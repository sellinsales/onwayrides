<?php

namespace App\Http\Controllers\Api;

use App\Contracts\Auth\FirebaseTokenVerifier;
use App\Exceptions\FirebaseAuthenticationException;
use App\Exceptions\FirebaseConfigurationException;
use App\Http\Controllers\Api\Concerns\ResolvesFirebaseRequestUser;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\FirebaseUserSyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Response;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class DriverDocumentController extends Controller
{
    use ResolvesFirebaseRequestUser;

    public function store(
        Request $request,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ): JsonResponse {
        $payload = $request->validate([
            'document_type' => ['required', Rule::in([
                'license',
                'cnic',
                'profile_photo',
                'police_clearance',
                'vehicle_registration',
                'route_permit',
                'other',
            ])],
            'document_number' => ['nullable', 'string', 'max:100'],
            'expiry_date' => ['nullable', 'date'],
            'document' => ['required', 'file', 'mimetypes:image/jpeg,image/png,image/webp,application/pdf', 'max:12288'],
        ]);

        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $driverProfile = DB::table('driver_profiles')->where('user_id', $user->id)->first();

            if ($driverProfile === null) {
                throw ValidationException::withMessages([
                    'document' => 'Start your driver application before uploading driver documents.',
                ]);
            }

            $uploadedFile = $request->file('document');
            if ($uploadedFile === null) {
                throw ValidationException::withMessages([
                    'document' => 'A document file is required.',
                ]);
            }

            $checksum = hash_file('sha256', $uploadedFile->getRealPath());
            $extension = strtolower($uploadedFile->getClientOriginalExtension() ?: $uploadedFile->extension() ?: 'bin');
            $filename = sprintf(
                'onwayrides-driver-%d-%s-%s.%s',
                $driverProfile->id,
                Str::slug((string) $payload['document_type']),
                $checksum,
                $extension
            );
            $relativePath = sprintf(
                'app/private/driver-documents/%d/%s/%s',
                $driverProfile->id,
                $payload['document_type'],
                $filename
            );

            $existing = DB::table('driver_documents')
                ->where('driver_profile_id', $driverProfile->id)
                ->where('document_type', $payload['document_type'])
                ->first();

            if ($existing !== null && $existing->file_url === $relativePath) {
                return response()->json([
                    'status' => 'ok',
                    'message' => 'This exact document is already on file.',
                    'document' => $this->serializeDocument($existing),
                ]);
            }

            Storage::disk('local')->putFileAs(
                dirname($relativePath),
                $uploadedFile,
                basename($relativePath)
            );

            $now = now();

            if ($existing !== null) {
                DB::table('driver_documents')
                    ->where('id', $existing->id)
                    ->update([
                        'document_number' => $payload['document_number'] ?? null,
                        'file_url' => $relativePath,
                        'status' => 'pending',
                        'expiry_date' => $payload['expiry_date'] ?? null,
                        'reviewed_by_user_id' => null,
                        'reviewed_at' => null,
                        'rejection_reason' => null,
                        'updated_at' => $now,
                    ]);

                $document = DB::table('driver_documents')->where('id', $existing->id)->first();
            } else {
                $documentId = DB::table('driver_documents')->insertGetId([
                    'driver_profile_id' => $driverProfile->id,
                    'document_type' => $payload['document_type'],
                    'document_number' => $payload['document_number'] ?? null,
                    'file_url' => $relativePath,
                    'status' => 'pending',
                    'expiry_date' => $payload['expiry_date'] ?? null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $document = DB::table('driver_documents')->where('id', $documentId)->first();
            }

            DB::table('driver_profiles')
                ->where('id', $driverProfile->id)
                ->update([
                    'onboarding_status' => 'review',
                    'updated_at' => $now,
                ]);
        } catch (FirebaseConfigurationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 503);
        } catch (FirebaseAuthenticationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 401);
        }

        return response()->json([
            'status' => 'ok',
            'message' => 'Driver document uploaded securely.',
            'document' => $this->serializeDocument($document),
        ]);
    }

    public function show(
        Request $request,
        int $documentId,
        FirebaseTokenVerifier $tokenVerifier,
        FirebaseUserSyncService $userSyncService
    ) {
        try {
            $user = $this->resolveAuthenticatedUser($request, $tokenVerifier, $userSyncService);
            $document = DB::table('driver_documents')->where('id', $documentId)->first();

            if ($document === null) {
                abort(404);
            }

            $driverProfile = DB::table('driver_profiles')->where('id', $document->driver_profile_id)->first();
            if ($driverProfile === null) {
                abort(404);
            }

            $canAccess = (int) $driverProfile->user_id === (int) $user->id
                || in_array($user->role, ['admin', 'support'], true);

            if (! $canAccess) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'You are not allowed to access this document.',
                ], 403);
            }

            $path = (string) $document->file_url;
            if ($path === '' || ! Storage::disk('local')->exists($path)) {
                abort(404);
            }

            $absolutePath = Storage::disk('local')->path($path);
            $mimeType = Storage::disk('local')->mimeType($path) ?: 'application/octet-stream';

            return Response::file($absolutePath, [
                'Content-Type' => $mimeType,
                'Cache-Control' => 'private, no-store, max-age=0',
                'X-Robots-Tag' => 'noindex, nofollow',
            ]);
        } catch (FirebaseConfigurationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 503);
        } catch (FirebaseAuthenticationException $exception) {
            return response()->json([
                'status' => 'error',
                'message' => $exception->getMessage(),
            ], 401);
        }
    }

    /**
     * @param object $document
     * @return array<string, mixed>
     */
    private function serializeDocument(object $document): array
    {
        return [
            'id' => (int) $document->id,
            'document_type' => (string) $document->document_type,
            'document_label' => Str::headline(str_replace('_', ' ', (string) $document->document_type)),
            'document_number' => $document->document_number,
            'status' => (string) $document->status,
            'status_label' => Str::headline(str_replace('_', ' ', (string) $document->status)),
            'expiry_date' => $document->expiry_date,
            'reviewed_at' => $document->reviewed_at ?? null,
            'rejection_reason' => $document->rejection_reason ?? null,
            'updated_at' => $document->updated_at,
        ];
    }
}

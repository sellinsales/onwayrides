<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = [
        'firebase_uid',
        'full_name',
        'first_name',
        'last_name',
        'email',
        'phone',
        'country_code',
        'password_hash',
        'role',
        'status',
        'avatar_url',
        'national_id_number',
        'referral_code',
        'referred_by_user_id',
        'email_verified_at',
        'phone_verified_at',
        'last_login_at',
        'metadata',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function getAuthPasswordName(): string
    {
        return 'password_hash';
    }

    public function getAuthPassword(): string
    {
        return (string) ($this->{$this->getAuthPasswordName()} ?? '');
    }
}

<?php

namespace App\Data;

final readonly class FirebaseIdentity
{
    public function __construct(
        public string $uid,
        public ?string $email = null,
        public ?string $phoneNumber = null,
        public ?string $displayName = null,
        public ?string $photoUrl = null,
        public bool $emailVerified = false,
        public array $claims = [],
    ) {
    }
}

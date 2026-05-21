<?php

namespace App\Contracts\Auth;

use App\Data\FirebaseIdentity;

interface FirebaseTokenVerifier
{
    public function verify(string $idToken): FirebaseIdentity;
}

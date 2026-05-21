<?php

declare(strict_types=1);

namespace App\Support;

use RuntimeException;

final class Router
{
    /** @var array<int, array{method: string, pattern: string, handler: callable}> */
    private array $routes = [];

    public function get(string $pattern, callable $handler): void
    {
        $this->add('GET', $pattern, $handler);
    }

    public function post(string $pattern, callable $handler): void
    {
        $this->add('POST', $pattern, $handler);
    }

    public function add(string $method, string $pattern, callable $handler): void
    {
        $this->routes[] = [
            'method' => strtoupper($method),
            'pattern' => $pattern,
            'handler' => $handler,
        ];
    }

    /**
     * @return array{status:int,data:array<string,mixed>}
     */
    public function dispatch(Request $request): array
    {
        foreach ($this->routes as $route) {
            if ($route['method'] !== $request->method()) {
                continue;
            }

            $pattern = preg_replace('#\{([a-zA-Z0-9_]+)\}#', '(?P<$1>[^/]+)', $route['pattern']);
            $regex = '#^' . $pattern . '$#';

            if ($pattern === null || preg_match($regex, $request->path(), $matches) !== 1) {
                continue;
            }

            $params = [];
            foreach ($matches as $key => $value) {
                if (!is_int($key)) {
                    $params[$key] = $value;
                }
            }

            return call_user_func($route['handler'], $request, $params);
        }

        return [
            'status' => 404,
            'data' => [
                'success' => false,
                'message' => 'Endpoint not found.',
            ],
        ];
    }
}

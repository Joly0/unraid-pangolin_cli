<?php
/* Pangolin CLI - shared log helpers
 *
 * Used by the settings page (inline recent-log tail) and by logwin.php
 * (the full-log popup). Reads across the current log plus any rotated
 * files (pangolin_cli.log, .log.1, .log.2 ...) so the view stays
 * populated right after a logrotate copytruncate, and colour-codes lines
 * (connect / disconnect / warning / error) consistently in both places.
 */

if (!defined('PANGOLIN_LOG')) {
    define('PANGOLIN_LOG', '/var/log/pangolin_cli.log');
}

/* Current + rotated log files, oldest first (chronological reading order).
 * Compressed rotations (.gz) are skipped - rotation is configured without
 * compression so every file is readable plain text. */
function pangolin_log_files(): array {
    $files = array_filter(glob(PANGOLIN_LOG . '*') ?: [], fn($f) => !str_ends_with($f, '.gz'));
    usort($files, fn($a, $b) => filemtime($a) <=> filemtime($b));
    return array_values($files);
}

/* CSS class for a log line. Connect/disconnect markers are matched first so
 * they win over the generic error/warning keyword rules. */
function pangolin_log_class(string $line): string {
    $patterns = [
        'pangolin-connect'    => '/====\s*pangolin (client )?(connect|start|up)/i',
        'pangolin-disconnect' => '/====\s*pangolin (client )?(disconnect|stop|down)/i',
        'error' => '/\b(error|err|fatal|panic|failed|failure|refused|denied|unauthorized|forbidden|timeout|timed out|unreachable|cannot|could not|unable)\b|\b[45]\d\d\b/i',
        'warn'  => '/\b(warn|warning|retry|retrying|deprecated)\b/i',
    ];
    foreach ($patterns as $class => $re) {
        if (preg_match($re, $line)) {
            return $class;
        }
    }
    return 'text';
}

/* Render lines as colour-coded <span> blocks for a <pre>. */
function pangolin_log_render(array $lines): string {
    $out = '';
    foreach ($lines as $line) {
        $line = rtrim($line, "\r\n");
        $cls  = pangolin_log_class($line);
        $out .= '<span class="' . $cls . '">' . htmlspecialchars($line === '' ? ' ' : $line) . "</span>\n";
    }
    return $out;
}

/* Last $n lines across current + rotated files (newest content kept). */
function pangolin_log_tail(int $n): array {
    $buf = [];
    foreach (array_reverse(pangolin_log_files()) as $f) {
        $lines = @file($f, FILE_IGNORE_NEW_LINES);
        if ($lines === false) {
            continue;
        }
        $buf = array_merge($lines, $buf);
        if (count($buf) >= $n) {
            break;
        }
    }
    return array_slice($buf, -$n);
}

/* All available log lines, optionally capped to the last $max. */
function pangolin_log_all(int $max = 0): array {
    $lines = [];
    foreach (pangolin_log_files() as $f) {
        $l = @file($f, FILE_IGNORE_NEW_LINES);
        if ($l !== false) {
            $lines = array_merge($lines, $l);
        }
    }
    if ($max > 0 && count($lines) > $max) {
        $lines = array_slice($lines, -$max);
    }
    return $lines;
}

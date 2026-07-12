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
 * they win over the error/warning rules. The olm client logs Go-style
 * line-leading level tokens ("ERROR: 2026/07/12 15:33:06 msg"), so those are
 * the primary signal; a short keyword fallback catches messages relayed from
 * elsewhere. Bare 4xx/5xx numbers and routine words (retry, timeout, cannot)
 * are deliberately not matched - they flagged byte counts and normal
 * reconnect chatter as errors. */
function pangolin_log_class(string $line): string {
    $patterns = [
        'pangolin-connect'    => '/====\s*pangolin (client )?(connect|start|up)/i',
        'pangolin-disconnect' => '/====\s*pangolin (client )?(disconnect|stop|down)/i',
        'error' => '/^(erro|error|fatal|panic):?\s|\b(error|fatal|panic|failed|failure|refused|denied|unauthorized|forbidden)\b/i',
        'warn'  => '/^(warn|warning):?\s|\b(warn(ing)?|deprecated)\b/i',
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

/* Last $n lines of one file, reading backwards in 8 KB chunks so a large
 * (multi-MB verbose) log never gets slurped whole. Line semantics match
 * file(FILE_IGNORE_NEW_LINES): no trailing newlines in elements, a final
 * unterminated line is included. */
function pangolin_tail_file(string $f, int $n): array {
    if ($n <= 0) {
        return [];
    }
    $fh = @fopen($f, 'rb');
    if ($fh === false) {
        return [];
    }
    fseek($fh, 0, SEEK_END);
    $pos = ftell($fh);
    $buf = '';
    while ($pos > 0) {
        $read = min(8192, $pos);
        $pos -= $read;
        fseek($fh, $pos, SEEK_SET);
        $buf = fread($fh, $read) . $buf;
        /* >$n newlines guarantees the last $n lines are complete even if the
         * chunk boundary split the first line in $buf. */
        if (substr_count($buf, "\n") > $n) {
            break;
        }
    }
    fclose($fh);
    if ($buf === '') {
        return [];
    }
    $lines = explode("\n", $buf);
    if (end($lines) === '') {
        array_pop($lines);   // trailing newline, not an empty last line
    }
    return array_slice($lines, -$n);
}

/* Last $n lines across current + rotated files (newest content kept). */
function pangolin_log_tail(int $n): array {
    $buf = [];
    foreach (array_reverse(pangolin_log_files()) as $f) {
        $need = $n - count($buf);
        if ($need <= 0) {
            break;
        }
        $buf = array_merge(pangolin_tail_file($f, $need), $buf);
    }
    return $buf;
}

/* Tail across all files, capped to the last $max lines (default 5000).
 * Non-positive $max means the default, never unlimited - the popup must not
 * load an unbounded amount of log into memory. */
function pangolin_log_all(int $max = 5000): array {
    return pangolin_log_tail($max > 0 ? $max : 5000);
}

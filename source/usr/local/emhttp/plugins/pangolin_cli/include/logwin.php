<?php
/* Pangolin CLI - full log popup
 *
 * Opened in a new browser window from the settings page ("View full log").
 * Shows the complete log (current + rotated files) colour-coded, so the user
 * has enough history for troubleshooting without dumping it on the settings
 * page itself. Self-contained styling so it renders regardless of theme.
 */
$docroot = $_SERVER['DOCUMENT_ROOT'] ?: '/usr/local/emhttp';
require_once "$docroot/plugins/pangolin_cli/include/log.php";

/* ?max= caps the line count; <=0 falls back to the 5000 default (there is no
 * "unlimited" - see pangolin_log_all) and 20000 is the hard ceiling. */
$max   = isset($_GET['max']) ? (int)$_GET['max'] : 5000;
$max   = min($max > 0 ? $max : 5000, 20000);
$lines = pangolin_log_all($max);
?>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Pangolin CLI &mdash; Full log</title>
<style>
  html,body{margin:0;height:100%;background:#1e1e1e;color:#ddd;
    font-family:Menlo,Consolas,"DejaVu Sans Mono",monospace;font-size:12px;}
  header{position:sticky;top:0;z-index:1;display:flex;align-items:center;gap:10px;
    padding:8px 12px;background:#2b2b2b;border-bottom:1px solid #444;}
  header b{color:#fff;font-family:sans-serif;}
  header .legend{margin-left:auto;font-family:sans-serif;font-size:11px;}
  header .legend span{padding:1px 7px;border-radius:3px;margin-left:6px;}
  button{font-family:sans-serif;cursor:pointer;padding:3px 10px;}
  pre{margin:0;padding:10px 12px;white-space:pre-wrap;word-break:break-word;}
  pre span{display:block;padding:0 4px;}
  .error{color:#ff8a8a;background:#3a1d1d;}
  .warn{color:#ffd27a;background:#3a331a;}
  .pangolin-connect{color:#92e69a;background:#1d3a23;font-weight:bold;}
  .pangolin-disconnect{color:#cfcfcf;background:#33302a;font-weight:bold;}
  .text{color:#dddddd;}
  .empty{padding:20px;color:#888;font-family:sans-serif;}
</style>
</head>
<body>
<header>
  <b>Pangolin CLI &mdash; Full log</b>
  <button onclick="location.reload()">Refresh</button>
  <button onclick="window.close()">Close</button>
  <span class="legend">
    <span class="pangolin-connect">connect</span>
    <span class="pangolin-disconnect">disconnect</span>
    <span class="warn">warning</span>
    <span class="error">error</span>
  </span>
</header>
<?php if ($lines): ?>
<pre id="log"><?=pangolin_log_render($lines)?></pre>
<script>window.scrollTo(0, document.body.scrollHeight);</script>
<?php else: ?>
<div class="empty">No log entries yet.</div>
<?php endif; ?>
</body>
</html>

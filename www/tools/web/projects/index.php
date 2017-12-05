<?php
?>
<!DOCTYPE html>
<html>
<head>
    <title>dev - project listing</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Helvetica, Arial; font-size: 80%; line-height: 150%">
<a href="/"><< back to menu</a><br />
<h1>local development - project listing</h1>
<h2>root projects</h2>

<?php

    foreach(glob('../../../*') as $dir)
        echo '<a href="'.$dir.'">' . basename($dir) . '</a><br />';
?>
</body>
</html>
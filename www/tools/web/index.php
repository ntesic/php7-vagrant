<?php
$links = array(
    '/projects/' 			=> 'Projects',
    '/database-admin/' 	=> 'phpMyAdmin',
    '/adminer/' 			=> 'Adminer (MSSQL)',
    '/memcached-admin/'	=> 'MemCache',
    '/opcache-status/opcache.php'	=> 'OpCache',
    '/webgrind/'	=> 'Webgrind',
    '/phpinfo/'			=> 'PHP Info'
);

function getNav($port = '80')
{
    global $links;

    $output = '<ul class="nav">';
    foreach($links as $url => $name)
        $output .= '<li><a href="http://tools.dev:'.$port.$url.'">'.$name.'</a></li>';
    $output .= '</ul>';

    return $output;
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Helvetica, Arial; font-size: 80%; line-height: 150%">
<h1>Local development - dashboard</a>
    <!--<h2>Apache (Port: 80)</h2>-->
    <?php
    //echo getNav();
    ?>
    <!--<h2>Nginx (Port: 81)</h2>-->
    <?php
    //echo getNav('81');
    ?>
    <h2>Webserver (Nginx)</h2>
    <?php
    echo getNav('80');
    ?>
</body>
</html>
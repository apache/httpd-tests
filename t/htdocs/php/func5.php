<?php

function foo()
{
        error_log("foo() has been called.", 0);
}

register_shutdown_function("foo");

print "foo() will be called on shutdown...\n";

?>

<?php

function foo()
{
        print "foo() has been called.\n";
}

register_shutdown_function("foo");

print "foo() will be called on shutdown...\n";

?>

<?php
	for($i=0;$i<$HTTP_SERVER_VARS["argc"];$i++) {
                echo "$i: ".$HTTP_SERVER_VARS["argv"][$i]."\n";
        }
?>

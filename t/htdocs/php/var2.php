<?php
	switch ($HTTP_SERVER_VARS["REQUEST_METHOD"]) {
	case "GET":
		echo join(" ", array($HTTP_GET_VARS["v1"],
				     $HTTP_GET_VARS["v2"]));
		break;
	case "POST":
		echo join(" ", array($HTTP_POST_VARS["v1"],
				     $HTTP_POST_VARS["v2"]));
		break;
	default:
		echo "ERROR!";
	}
?>

<?php
	switch ($HTTP_SERVER_VARS["REQUEST_METHOD"]) {
	case "GET":
		echo $HTTP_GET_VARS["variable"];
		break;
	case "POST":
		echo $HTTP_POST_VARS["variable"];
		break;
	default:
		echo "ERROR!";
	}
?>

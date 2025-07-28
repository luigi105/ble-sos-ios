
	<?php
	header('Access-Control-Allow-Origin: *');
//	date_default_timezone_set("America/Argentina/Buenos_Aires");
	date_default_timezone_set("America/Chicago");
	include("dbin/db.php");
	
function test_input($data) {
  $data = trim($data);
  $data = stripslashes($data);
  $data = htmlspecialchars($data);
  return $data; }
	$location  = "init";
	//$loc = $_POST["loc"];
	//$prize = $_POST["prize"];
	//$pointscost = $_POST["cost"];
	//$local = $_POST["local"];   /// para locationB
	
	if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (isset($_POST["mac_address"])) {
	$location = test_input($_POST["mac_address"]);
	 
//	 $prizeid = $uid.$codigo;
	
	/*echo $uid."</br>";
	echo $pointscost."</br>";
	echo $local."</br>";*/
   $pointscount=0;
	
	//$date = date('Y-m-d'); 
		
	if($location != ""){
			
			
		 
	/*	$mSQL="UPDATE members SET points='".$newuserpoints."', pointscount='".$pointscount."' WHERE id='".$uid."'  ";
	    if ($con->query($mSQL) === TRUE) {
		$status1 ="";
		} else {
			echo "Error updating record: " . $con->error;
				}
				$redeemcode=$uid."P".$pointscount;	*/	
		//  $usql="INSERT INTO userspointsdetail (codigo, locationB, username, lastname, license, points, prizename, phone, tier, redeemcode, deliverdate) VALUES ('".$uid."', '".$local."', '".$name."', '".$lastname."', '".$license."', '".$pointscost."', '".$prize."', '".$phone."', '".$tier."', '".$redeemcode."', '".$date."')";		
		 $usql="INSERT INTO gps_users (location) VALUES ('".$location."')";
		 if (mysqli_query($con, $usql)) {	
			 
	} else {
 //   echo "Error updating record: " . $con->error;
	}
			
	//	echo "1";
		 
		
		 }
		 
	}
	}
mysqli_close($con);		 
	
	/*
	
	$rsql = "SELECT id, username, lastname, points, license, phone, tier, pointscount FROM members WHERE id='".$uid."'  ";
	//$sql = 'SELECT today, delivered FROM usersdetail WHERE today="'.$date.'" AND id="'.$uid.'"  ';
	$rsql= str_replace("\'","",$rsql);
	$resultado = mysqli_query($con,$rsql);	
	
 	if ($resultado->num_rows > 0) {
    
		$row = $resultado->fetch_assoc();
		
		$name= $row["username"];
		$lastname = $row["lastname"];
		$userpoints= $row["points"];
		$license = $row["license"];	
		$phone = $row["phone"];	
		$tier = $row["tier"];			
		$pointscount=$row["pointscount"];
		
		if($userpoints >= $pointscost){
			
			$newuserpoints = $userpoints-$pointscost;        
			$pointscount=$pointscount+1;
		 
		$mSQL="UPDATE members SET points='".$newuserpoints."', pointscount='".$pointscount."' WHERE id='".$uid."'  ";
	    if ($con->query($mSQL) === TRUE) {
		$status1 ="";
		} else {
			echo "Error updating record: " . $con->error;
				}
				$redeemcode=$uid."P".$pointscount;		
		  $usql="INSERT INTO userspointsdetail (codigo, locationB, username, lastname, license, points, prizename, phone, tier, redeemcode, deliverdate) VALUES ('".$uid."', '".$local."', '".$name."', '".$lastname."', '".$license."', '".$pointscost."', '".$prize."', '".$phone."', '".$tier."', '".$redeemcode."', '".$date."')";		
		 if (mysqli_query($con, $usql)) {	
			 
	} else {
    echo "Error updating record: " . $con->error;
	}
			
		echo "1";
		 
		
		 }
		
		 }
		
	  mysqli_close($con);	

*/
	   
	?>




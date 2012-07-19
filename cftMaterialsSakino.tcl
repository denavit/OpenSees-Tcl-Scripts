proc OpenSeesComposite::ccftConcreteSakino { matTag fc D t Fy units} {
	# ###########################################################
	# ccftConcreteSakino $matTag $fc $D $t $Fy $units
	# ###########################################################
	# Sakino et al. 2004 CCFT Concrete Model:
	# This function creates a Concrete04 uniaxialMaterial with parameters
	# intended to mimic the concrete model of Sakino et al. 2004
	#
	# Input Parameters:
	# matTag - integer tag for uniaxialMaterial
	# fc - compressive strength of the concrete core
	# D - outside diameter of the steel tube
	# t - thickness of the steel tube
	# Fy - steel yield stress
	# units - unit system
	#    - US = United States customary units (i.e., kips, inches, ksi)
	#    - SI = International System of Units (i.e., N, mm, MPa)
	#
	# References:
	# Sakino, K. et al. (2004). "Behavior of Centrally Loaded Concrete-Filled Steel-Tube
	# Short Columns," Journal of Structural Engineering, Vol. 130, pp. 180.

	set fc  [expr double($fc)]
	set D   [expr double($D)]
	set t   [expr double($t)]
	set Fy  [expr double($Fy)]

    if { $fc <= 0.0 } {
        puts "Warning - ccftConcreteSakino: fc should be input as a posititve value"
        set fc [expr -1*$fc]
    }
    if { $D <= 0.0 } {
        puts "Error - ccftConcreteSakino: D should be input as a posititve value"
        exit
    }
    if { $t <= 0.0 } {
        puts "Error - ccftConcreteSakino: t should be input as a posititve value"
        exit
    }
    if { $Fy <= 0.0 } {
        puts "Error - ccftConcreteSakino: Fy should be input as a posititve value"
        exit
    }


	set alfaVM  -0.19 ; # alfa from VonMises
	set fr      [expr -2*$t*$alfaVM*$Fy/($D-2*$t)]
    set sre     [expr (4.1/23)*$fr]

	switch -exact -- $units {
		US {
			set ksi2MPa 6.89476
			set MPa2ksi [expr 1.0/$ksi2MPa]
			set gammau  [expr 1.67*pow($D*25.4,-0.112)]
			set fcp     [expr $gammau*$fc]
			set Ec      [expr (6.90+3.32*sqrt(abs($fcp)*$ksi2MPa))*1.e3*$MPa2ksi]
			set eco     [expr 0.94*pow(abs($fcp)*$ksi2MPa,0.25)*1.0e-3]
            set W       [expr 1.50 - 17.1e-3*abs($fcp)*$ksi2MPa + 2.39*sqrt(abs($sre)*$ksi2MPa)]

		}
		SI {
			set gammau  [expr 1.67*pow($D,-0.112)]
			set fcp     [expr $gammau*$fc]
			set Ec      [expr (6.90+3.32*sqrt(abs($fcp)))*1.e3]
			set eco     [expr 0.94*pow(abs($fcp),0.25)*1.0e-3]
            set W       [expr 1.50 - 17.1e-3*abs($fcp) + 2.39*sqrt(abs($sre))]
		}
		default {
			puts "ERROR: units not recgonized"
			exit
		}
	}

	set K   [expr 1.0 + 4.1*abs($fr/$fcp)]
	set fcc [expr $K*$fcp]
	if {$K <= 1.5}  {
		set ecc [expr $eco*(1.0 + 4.7*($K-1)) ]
	} else {
		set ecc [expr $eco*(3.4 + 20.0*($K-1)) ]
	}


	#uniaxialMaterial sakinoSunConcrete04 tag fcc ecc Ec W
	uniaxialMaterial sakinoSunConcrete04 $matTag -$fcc -$ecc $Ec $W
}

proc OpenSeesComposite::rcftConcreteSakino { matTag fc D t Fy units} {
	# ###########################################################
	# rcftConcreteSakino $matTag $fc $D $t $Fy $units
	# ###########################################################
	# Sakino et al. 2004 RCFT Concrete Model:
	# This function creates a XXX uniaxialMaterial with parameters
	# intended to mimic the concrete model of Sakino et al. 2004
	#
	# Input Parameters:
	# matTag - integer tag for uniaxialMaterial
	# fc - compressive strength of the concrete core
	# D - outside diameter of the steel tube
	# t - thickness of the steel tube
	# Fy - steel yield stress
	# units - unit system
	#    - US = United States customary units (i.e., kips, inches, ksi)
	#    - SI = International System of Units (i.e., N, mm, MPa)
	#
	# References:
	# Sakino, K. et al. (2004). "Behavior of Centrally Loaded Concrete-Filled Steel-Tube
	# Short Columns," Journal of Structural Engineering, Vol. 130, pp. 180.

	set fc  [expr double($fc)]
	set D   [expr double($D)]
	set t   [expr double($t)]
	set Fy  [expr double($Fy)]

    if { $fc <= 0.0 } {
        puts "Warning - rcftConcreteSakino: fc should be input as a posititve value"
        set fc [expr -1*$fc]
    }
    if { $D <= 0.0 } {
        puts "Error - rcftConcreteSakino: D should be input as a posititve value"
        exit
    }
    if { $t <= 0.0 } {
        puts "Error - rcftConcreteSakino: t should be input as a posititve value"
        exit
    }
    if { $Fy <= 0.0 } {
        puts "Error - rcftConcreteSakino: Fy should be input as a posititve value"
        exit
    }

	set sre [expr 2.*pow($t,2)*($D-$t)*$Fy/pow($D-2.*$t,3)]

	switch -exact -- $units {
		US {
			set ksi2MPa 6.89476
			set MPa2ksi [expr 1.0/$ksi2MPa]
			set gammau  [expr 1.67*pow($D*25.4,-0.112)]
			set fcp     [expr $gammau*$fc]
			set Ec      [expr (6.90+3.32*sqrt(abs($fcp)*$ksi2MPa))*1.e3*$MPa2ksi]
			set eco     [expr 0.94*pow(abs($fcp)*$ksi2MPa,0.25)*1.0e-3]
            set W       [expr 1.50 - 17.1e-3*abs($fcp)*$ksi2MPa + 2.39*sqrt(abs($sre)*$ksi2MPa)]
		}
		SI {
			set gammau  [expr 1.67*pow($D,-0.112)]
			set fcp     [expr $gammau*$fc]
			set Ec      [expr (6.90+3.32*sqrt(abs($fcp)))*1.e3]
			set eco     [expr 0.94*pow(abs($fcp),0.25)*1.0e-3]
            set W       [expr 1.50 - 17.1e-3*abs($fcp) + 2.39*sqrt(abs($sre))]
		}
		default {
			puts "ERROR: units not recgonized"
			exit
		}
	}

	#uniaxialMaterial sakinoSunConcrete04 tag fcc ecc Ec W
	uniaxialMaterial sakinoSunConcrete04 $matTag -$fcp -$eco $Ec $W
}

proc OpenSeesComposite::rcftSteelSakino { matTag Fy Es B t} {
	# ###########################################################
	# rcftSteelSakino $matTag $Fy $Es $B $t
	# ###########################################################
	# Sakino et al. 2004 RCFT Steel Model
	# This function creates a ElasticPP uniaxialMaterial with parameters
	# intended to mimic the steel model of Sakino et al. 2004
	#
	# Input Parameters:
	# matTag - integer tag for uniaxialMaterial
	# Fy - steel yield stress
	# Es - steel elastic modulus
	# B - width of steel tube
	# t - thickness of steel tube
	#
	# Notes:
	# - This function is dimensionally consistent, so no unit system needs to be defined
	#
	# References:
	# Sakino, K. et al. (2004). "Behavior of Centrally Loaded Concrete-Filled Steel-Tube
	# Short Columns," Journal of Structural Engineering, Vol. 130, pp. 180.

	set Fy  [expr double($Fy)]
	set Es  [expr double($Es)]
	set B   [expr double($B)]
	set t   [expr double($t)]

	set rootAlphaS [expr ($B/$t)*sqrt($Fy/$Es)]
	set ssT        [expr (1.19 - 0.207*$rootAlphaS)*$Fy]

	if { $rootAlphaS <= 1.54 } {
		# Type 1
		set Seq11 [expr 1.0/(0.698 + 0.128*pow($B/$t,2)*($Fy/$Es))]
		set esB   [expr (6.06/pow($rootAlphaS,2) - 0.801/$rootAlphaS + 1.10)*($Fy/$Es)]
		set esE   [expr $Fy/$Es]
		set esT   [expr $esB + 3.59*$esE]

		set s1p [expr $Fy]
		set e1p [expr $Fy/$Es]
		set s2p [expr $Fy]
		set e2p [expr $Fy/$Es + 1]
		set s3p [expr $Fy]
		set e3p [expr $Fy/$Es + 2]
		set s1n [expr -1*$Fy]
		set e1n [expr -1*$Fy/$Es]
		set s2n [expr -1*$Fy*$Seq11]
		set e2n [expr -1*$esB]
		set s3n [expr -1*$ssT]
		set e3n [expr -1*$esT]
	} elseif { $rootAlphaS > 1.54 && $rootAlphaS < 2.03 } {
		# Type 2
		set esB   [expr $Fy/$Es]
		set esE   [expr $Fy/$Es]
		set esT   [expr $esB + 3.59*$esE]

		set s1p [expr $Fy]
		set e1p [expr $Fy/$Es]
		set s2p [expr $Fy]
		set e2p [expr $Fy/$Es + 1]
		set s3p [expr $Fy]
		set e3p [expr $Fy/$Es + 2]
		set s1n [expr -1*$Fy]
		set e1n [expr -1*$Fy/$Es]
		set s2n [expr -1*$ssT]
		set e2n [expr -1*$esT]
		set s3n [expr -1*$ssT]
		set e3n [expr -1*$esT - 1]
	} elseif { $rootAlphaS >= 2.03 } {
		# Type 3
		set Seq12 [expr 1.0/(0.698 + 0.128*pow($B/$t,2)*($Fy/$Es)*(4.00/6.97))]
		set ssB   [expr $Fy*$Seq12]
		set esB   [expr $ssB/$Es]
		set esE   [expr $ssB/$Es]
		set esT   [expr $esB + 3.59*$esE]

		set s1p [expr $Fy]
		set e1p [expr $Fy/$Es]
		set s2p [expr $Fy]
		set e2p [expr $Fy/$Es + 1]
		set s3p [expr $Fy]
		set e3p [expr $Fy/$Es + 2]
		set s1n [expr -1*$ssB]
		set e1n [expr -1*$ssB/$Es]
		set s2n [expr -1*$ssT]
		set e2n [expr -1*$esT]
		set s3n [expr -1*$ssT]
		set e3n [expr -1*$esT - 1]
	} else {
		puts "Error in rcftSteelSakino"
		exit
	}

	#uniaxialMaterial Hysteretic $matTag $s1p $e1p $s2p $e2p <$s3p $e3p> $s1n $e1n $s2n $e2n <$s3n $e3n> $pinchX $pinchY $damage1 $damage2 <$beta>
	uniaxialMaterial  Hysteretic $matTag $s1p $e1p $s2p $e2p  $s3p $e3p  $s1n $e1n $s2n $e2n  $s3n $e3n  0.0     1.0     0.0      0.0      0.0

	#uniaxialMaterial Pinching4 $matTag  $ePf1 $ePd1 $ePf2 $ePd2 $ePf3 $ePd3 $ePf4 $ePd4           <$eNf1 $eNd1 $eNf2 $eNd2 $eNf3 $eNd3 $eNf4 $eNd4>          $rDispP $rForceP $uForceP <$rDispN $rForceN $uForceN > $gK1 $gK2 $gK3 $gK4 $gKLim $gD1 $gD2 $gD3 $gD4 $gDLim $gF1 $gF2 $gF3 $gF4 $gFLim $gE $dmgType
	#uniaxialMaterial Pinching4  $matTag  $s1p  $e1p  $s2p  $e2p  $s3p  $e3p  $s3p  [expr $e3p+1.0]  $s1n  $e1n  $s2n  $e2n  $s3n  $e3n  $s3n  [expr $e3n-1.0]  0.95     1.0      0.95       1.0    1.0    0.0      0.0  0.0  0.0  0.0  0.0    0.0  0.0  0.0  0.0  0.0    0.0  0.0  0.0  0.0  0.0    0.0 "cycle"
}

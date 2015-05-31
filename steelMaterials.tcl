proc OpenSeesComposite::shenSteelMaterial { matTag Es Fy Fu eu units args} {
    # ###################################################################
    # shenSteelMaterial $matTag $Es $Fy $Fu $eu $units $args
    # ###################################################################
    # create a unaxialMaterial object using the shenSteel01 material
    #
    # Required Input Parameters:
    #   $matTag - integer tag for uniaxialMaterial
    #   $Es - elastic modulus
    #   $Fy - yield stress
    #   $Fu - ultimate stress
    #   $eu - strain at ultimate stress
    #   $units - unit system
    #     US = United States customary units (i.e., kips, inches, ksi)
    #     SI = International System of Units (i.e., N, mm, MPa)
    #
    # Optional Input:
    #   -type $type - set type of model
   	#   -initialStress $initialStress - inital stress of the material used
    #      to model residual stresses (must be in the elastic range)
   	#   -initialPlasticStrain $epo - inital plastic strain
    #   -initialPlasticModulus $Epst

    # ########### Set Constants and Default Values ###########
    set extraArgs       [list]
    set type            null
    set Epst_input      -1
    set initialStress   0.0
    set epo             0.0
    set alphaLat        0.0
    set elb             0.0
    set lbDegEp_rate    0.0
    set lbDegKappa_rate 0.0
    set lbDegFulb_rate  0.0

    # ############### Check Input Data ###############
	set Es [expr double($Es)]
    if { $Es <= 0.0 } {
        error "Error - shenSteelMaterial: Es should be input as a posititve value"
    }
    set Fy [expr double($Fy)]
    if { $Fy <= 0.0 } {
        error "Error - shenSteelMaterial: Fy should be input as a posititve value"
    }
    set Fu [expr double($Fu)]
    if { $Fu < $Fy } {
        error "Error - shenSteelMaterial: Fu should be greater than Fy"
    }
    set eu [expr double($eu)]
    if { $eu <= 0.0 } {
        error "Error - shenSteelMaterial: eu should be input as a posititve value"
    }


    # ########### Read Optional Input ###########
    for { set i 0 } { $i < [llength $args] } { incr i } {
		set param [lindex $args $i]
        if { $param == "-initialStress" } {
            set initialStress [lindex $args [expr $i+1]]
            incr i 1
            set initialStress [expr double($initialStress)]
            if { $initialStress <= -$Fy || $initialStress >= $Fy} {
                error "Error - shenSteelMaterial: initialStress should be in the elastic range"
            }
            continue
		}
        if { $param == "-initialPlasticStrain" } {
            set epo [lindex $args [expr $i+1]]
            incr i 1
            set epo [expr double($epo)]
            if { $epo <= 0.0 } {
                error "Error - shenSteelMaterial: epo should be input as a posititve value"
            }
            continue
		}
        if { $param == "-initialPlasticModulus" } {
            set Epst_input [lindex $args [expr $i+1]]
            incr i 1
            set Epst_input [expr double($Epst_input)]
            if { $Epst <= 0.0 } {
                error "Error - shenSteelMaterial: Epst should be input as a posititve value"
            }
            continue
		}
        if { $param == "-type" } {
            set type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-biaxialStress" } {
            set alphaLat [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-localBuckling" } {
            set elb          [lindex $args [expr $i+1]]
            set lb_Ksft      [lindex $args [expr $i+2]]
            set lb_alphaFulb [lindex $args [expr $i+3]]
            set lb_ref       [lindex $args [expr $i+4]]
            incr i 4
            continue
		}
        if { $param == "-localBucklingDegradationEp" } {
            set lbDegEp_rate  [lindex $args [expr $i+1]]
            set lbDegEp_limit [lindex $args [expr $i+2]]
            incr i 2
            continue
		}
        if { $param == "-localBucklingDegradationKappa" } {
            set lbDegKappa_rate  [lindex $args [expr $i+1]]
            set lbDegKappa_limit [lindex $args [expr $i+2]]
            incr i 2
            continue
		}
        if { $param == "-localBucklingDegradationFulb" } {
            set lbDegFulb_rate  [lindex $args [expr $i+1]]
            set lbDegFulb_limit [lindex $args [expr $i+2]]
            incr i 2
            continue
		}
        error "Error - shenSteelMaterial: unknown optional parameter: $param"
	}

    # Shen Steel Model Parameters
	shenSteelProperties $Fy $Es $units kappaBar0 Ep0i alpha a b c omega zeta e f epst Epst M
    if { $Epst_input != -1 } {
      set Epst $Epst_input
    }

    # ############### Material Type ###############
    switch -exact -- $type {
        hotRolled {
            set epst 0.0
            set M    0.0
            set Epst [expr $Es/100.0]
            lappend extraArgs "-hotRolled" $epst $M $Epst
        }
        coldFormed {
            lappend extraArgs "-coldFormed" $epo $Epst
        }
        coldFormed2 {
            lappend extraArgs "-coldFormed2" $epo
        }
        CFT {
            set Epst [expr $Es/100.0]
            lappend extraArgs "-coldFormed" $epo $Epst
        }
        default {
            error "ERROR: shenSteelMaterial - type not recgonized -- $type"
        }
    }

    # Initial Stress
    if { $initialStress != 0.0 } {
        lappend extraArgs "-initialStress" $initialStress
    }

    # Biaxial Stress
    if { $alphaLat != 0.0 } {
        lappend extraArgs "-biaxialStress" $alphaLat
    }

    # Local Buckling
    if { $elb != 0.0 } {
        lappend extraArgs "-localBuckling" $elb $lb_Ksft $lb_alphaFulb $lb_ref

        if { $lbDegEp_rate != 0.0 } {
            lappend extraArgs "-localBucklingDegradationEp" $lbDegEp_rate $lbDegEp_limit
        }
        if { $lbDegKappa_rate != 0.0 } {
            lappend extraArgs "-localBucklingDegradationKappa" $lbDegKappa_rate $lbDegKappa_limit
        }
        if { $lbDegFulb_rate != 0.0 } {
            lappend extraArgs "-localBucklingDegradationFulb" $lbDegFulb_rate $lbDegFulb_limit
        }
    }

	# Define Material
    eval uniaxialMaterial shenSteel01 $matTag $Es $Fy $Fu $eu $kappaBar0 $Ep0i \
        $alpha $a $b $c $omega $zeta $e $f $extraArgs	
    # uniaxialMaterial shenSteel01 $matTag $Es $Fy $Fu $eu $kappaBar0 $Ep0i \
    #     $alpha $a $b $c $omega $zeta $e $f {*}$extraArgs
}


proc OpenSeesComposite::shenSteelProperties { Fy Es units kappaBar0_n \
    Ep0i_n alpha_n a_n b_n c_n omega_n zeta_n e_n f_n epst_n Epst_n M_n } {
	# ###################################################################
	# shenSteelProperties $Fy $Es $units $kappaBar0 $Ep0i $alpha $a $b $c $omega $zeta $e $f $epst $Epst $M
	# ###################################################################
	# Set steel material properties aggoring to values as reported in
    # Mamaghani et al. 1996
	#
	# Input Parameters:
	# Fy - steel yield stress
    # Es - steel elastic modulus
	# units - unit system
	#    - US = United States customary units (i.e., kips, inches, ksi)
	#    - SI = International System of Units (i.e., N, mm, MPa)
    # kappaBar0          size of the initial bounding lines
    # Ep0i               slope of the initial bounding lines
    # alpha, a, b, c     constants in the equation to compute the reduction in the elastic range
    # omega              constant in the equation to compute the slope of the bounding line
    # zeta               constant in the equation to compute the size of the bounding line
    # e, f               constants in the equation to compute the shape parameter (for the plastic modulus)
    # epst               plastic strain at the end of the yield plateau under monotonic loading
    # Epst               plastic modulus at initial hardening under monotonic loading
    # M                  constant in the equation to determine if the yield plateau still continues

    # Check input
    if { $Fy <= 0.0 } {
        error "Error - shenSteelProperties: Fy should be input as a posititve value"
    }
    if { $Es <= 0.0 } {
        error "Error - shenSteelProperties: Es should be input as a posititve value"
    }
    set Fy  [expr double($Fy)]
    set Es  [expr double($Es)]


    # Link the input variables to the function variables
    upvar $kappaBar0_n kappaBar0
    upvar $Ep0i_n      Ep0i
    upvar $alpha_n     alpha
    upvar $a_n         a
    upvar $b_n         b
    upvar $c_n         c
    upvar $omega_n     omega
    upvar $zeta_n      zeta
    upvar $e_n         e
    upvar $f_n         f
    upvar $epst_n      epst
    upvar $Epst_n      Epst
    upvar $M_n         M


	# Unit System Stuff
	switch -exact -- $units {
		US {
			set Fya 52
			set Fyb 40
		}
		SI {
			set Fya 358.5
			set Fyb 275.8
		}
		default {
			error "ERROR: shenSteelProperties: units not recgonized"
		}
	}


    # Set Shen Steel Model Parameters
	if { $Fy > $Fya } {
		set Epst        [expr 1.02e-2*$Es]
		set epst        0.00
        set a           -0.553
		set b           6.47
		set c           34.8
		set alpha       0.175
		set e           7.00e2; # 1.04e3
		set f           [expr 0.361*$Es]
        set M           0.00
		set Ep0i        [expr 7.85e-3*$Es]
		set omega       [expr 2.67/$Fy]
		set kappaBar0   [expr 1.06*$Fy]
		set zeta        [expr 8.04e-3/pow($Fy/$Es,2)]

	} elseif { $Fy > $Fyb && $Fy <= $Fya } {
		set Epst        [expr 3.40e-2*$Es]
		set epst        1.24e-2
        set a           -0.528
		set b           1.88
		set c           18.7
		set alpha       0.217
		set e           3.16e2
		set f           [expr 0.484*$Es]
        set M           -0.052
		set Ep0i        [expr 1.01e-2*$Es]
		set omega       [expr 4.0/$Fy]
		set kappaBar0   [expr 1.13*$Fy]
		set zeta        [expr 1.52e-3/pow($Fy/$Es,2)]

	} elseif { $Fy <= $Fyb } {
		set Epst        [expr 2.49e-2*$Es]
		set epst        1.53e-2
		set a           -0.505
		set b           2.17
		set c           14.4
		set alpha       0.191
		set e           5.00e2
		set f           [expr 0.300*$Es]
		set M           -0.37
        set Ep0i        [expr 8.96e-3*$Es]
		set omega       [expr 3.08/$Fy]
		set kappaBar0   [expr 1.15*$Fy]
        set zeta        [expr 9.89e-4/pow($Fy/$Es,2)]

	}
}


proc OpenSeesComposite::defaultValue_Fu {Fy units} {
  # ###########################################################
  # defaultValue_Fu $Fy $units
  # ###########################################################
  #
  # Input Parameters:
  # Fy    - steel yield stress
  # units - unit system ("US" or "SI")

  set Fy  [expr double($Fy)]

  switch -exact -- $units {
    US { set Fu [expr ((187.0*pow($Fy,-1.61))+1)*$Fy] }
    SI { set Fu [expr ((4190.0*pow($Fy,-1.61))+1)*$Fy] }
    default { error "ERROR - deafultValue_Fu: units not recgonized" }
  }  

  return $Fu
}


proc OpenSeesComposite::defaultValue_Es {units} {
  # ###########################################################
  # defaultValue_Es $units
  # ###########################################################
  #
  # Input Parameters:
  # units - unit system ("US" or "SI")

  switch -exact -- $units {
    US { set Es 29000.0 }
    SI { set Es 200000.0 }
    default { error "ERROR - defaultValue_Es: units not recgonized" }
  }  

  return $Es
}


proc OpenSeesComposite::hssSteelAbdelRahman {matTag Fy Es args} {
  # ###########################################################
  # hssSteelAbdelRahman $matTag $Fy $Es
  # hssSteelAbdelRahman $matTag $Fy $Es -corner $Fu $r $t
  # ###########################################################
  # Abdel-Rahman and Sivakumaran 1997 Cold-Formed Steel Model:
  # This function creates a uniaxialMaterial with parameters
  # intended to mimic the steel model of Abdel-Rahman and Sivakumaran 1997
  #
  # Input Parameters:
  # matTag - integer tag for uniaxialMaterial
  # Fy - steel yield stress
  # Es - steel elastic modulus
  # Fu - steel ultimate stress
  # r  - radius of corner
  # t  - thickness of steel tube
  #
  # Notes:
  # - This function is dimensionally consistent, so no unit system needs to be defined
  #
  # References:
  # 1. Abdel-Rahman, N., and Sivakumaran, K. S. (1997). “Material Properties
  #    Models for Analysis of Cold-Formed Steel Members.” Journal of Structural
  #    Engineering, 123(9), 1135-1143.

  set Fy [expr double($Fy)]
  set Es [expr double($Es)]
  set rs 0.75

  # ########### Read Optional Input ###########
  for { set i 0 } { $i < [llength $args] } { incr i } {
    set param [lindex $args $i]
    if { $param == "-corner" } {
      set Fu  [expr double([lindex $args [expr $i+1]])]
      set r   [expr double([lindex $args [expr $i+2]])]
      set t   [expr double([lindex $args [expr $i+3]])]
      incr i 3
      set Bc  [expr 3.69*($Fu/$Fy) - 0.819*($Fu/$Fy)*($Fu/$Fy) - 1.79]
      set m   [expr 0.192*($Fu/$Fy) - 0.068]
      set DFy [expr 0.60*($Bc/pow($r/$t,$m)-1)*$Fy]
      set Fy  [expr $Fy+$DFy]
      continue
    }
    if { $param == "-ResidualStressParameter" } {
      set rs [expr double([lindex $args [expr $i+1]])]
      incr i 1
      if { $rs > 1.0 || $rs < 0.0} {
        error "ERROR: hssSteelAbdelRahman: residual stress parameter should be between 0 and 1 ($rs)"
      }
      continue
    }
    error "Error - hssSteelAbdelRahman: unknown optional parameter: $param"
  }

  set s1  [expr $rs*$Fy]
  set s2  [expr (1.0-0.5*(1.0-$rs))*$Fy]
  set s3  [expr $Fy]

  set E1  [expr $Es]
  set E2  [expr 0.5*$Es]
  set E3  [expr 0.1*$Es]
  set E4  [expr 0.005*$Es]

  set e1  [expr $s1/$E1]
  set e2  [expr $e1+($s2-$s1)/$E2]
  set e3  [expr $e2+($s3-$s2)/$E3]

  uniaxialMaterial multiSurfaceKinematicHardening $matTag \
    -StressStrainSymmetric $s1 $e1 $s2 $e2 $s3 $e3 $E4
}

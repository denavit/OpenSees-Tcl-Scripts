proc OpenSeesComposite::changManderConcreteMaterial { matTag fc units args} {
  # ###################################################################
  # changManderConcreteMaterial $matTag $fc $units <options>
  # ###################################################################
  # create a unaxialMaterial object using the changMadnderConcrete01 model
  #
  # Required Input Parameters:
  #   $matTag - integer tag for uniaxialMaterial
  #   $fc - compressive strength of the concrete core (cylinder strength)
  #   $units - unit system
  #     US = United States customary units (i.e., kips, inches, ksi)
  #     SI = International System of Units (i.e., N, mm, MPa)
  #
  # Optional Input:
  #   -biaxial $fl - model a biaxial state of stress
  #   -symmetric $fl - model a symmetric triaxial state of stress
  #   -triaxial $fl1 $fl2 - model a general triaxial state of stress
  #   -cover - set confinement to zero and model spalling
  #   -spall $xcr - model spalling
  #   -tension - set the type of tension to use
  #   -Ec - set the type of Ec to use
  #   -ec - set the type of ec to use
  #   -r - set the type of r to use
  #

    # ########### Set Constants and Default Values ###########
    set extraArgs [list]
    set fl1 0.0
    set fl2 0.0
    set tension_type ChangMander
    set rn_pre_type  ChangMander
    set rn_post_type ChangMander
    set Ec_type      design
    set ec_type      ChangMander

    # ########### Read Optional Input ###########
    for { set i 0 } { $i < [llength $args] } { incr i } {
		set param [lindex $args $i]
		if { $param == "-biaxial" } {
            set fl1 [lindex $args [expr $i+1]]
            set fl2 0.0
            incr i 1
            continue
		}
		if { $param == "-symmetric" } {
            set fl1 [lindex $args [expr $i+1]]
            set fl2 $fl1
            incr i 1
            continue
		}
		if { $param == "-triaxial" } {
            set fl1 [lindex $args [expr $i+1]]
            set fl2 [lindex $args [expr $i+2]]
            incr i 2
            continue
		}
		if { $param == "-cover" } {
            set fl1 0.0
            set fl2 0.0
            lappend extraArgs "-spall" 2.0
            continue
		}
		if { $param == "-spall" } {
            set xcr [lindex $args [expr $i+1]]
            incr i 1
            lappend extraArgs "-spall" $xcr
            continue
		}
        if { $param == "-tension" } {
            set tension_type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-Ec" } {
            set Ec_type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-ec" } {
            set ec_type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-rn_pre" } {
            set rn_pre_type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-rn_post" } {
            set rn_post_type [lindex $args [expr $i+1]]
            incr i 1
            continue
		}
        if { $param == "-r" } {
            set rn_pre_type [lindex $args [expr $i+1]]
            set rn_post_type $rn_pre_type
            incr i 1
            continue
		}
        error "Error - changManderConcreteMaterial: unknown optional parameter: $param"
	}


    # ############### Check Input Data ###############
	set fc  [expr double($fc)]
    if { $fc <= 0.0 } {
        puts "Warning - changManderConcreteMaterial: fc should be input as a positive value"
        set fc [expr -1*$fc]
    }

    set fl1 [expr double($fl1)]
	set fl2 [expr double($fl2)]
    if { $fl1 < 0.0 || $fl2 < 0.0 } {
        error "Error - changManderConcreteMaterial: confinement pressure should be input as a positive value"
    }
    # Make sure fl2 is the greater value
    if { $fl2 < $fl1 } {
        set temp $fl1
        set $fl1 $fl2
        set $fl2 $fl1
    }


    # ############### Intial Stiffness ###############
    switch -exact -- $Ec_type {
        ChangMander {
            switch -exact -- $units {
                US { set Ec [expr (8200.0*pow($fc*6.89476,0.375))/6.89476] }
                SI { set Ec [expr 8200.0*pow($fc,0.375)] }
                default { error "ERROR: units not recgonized" }
            }
        }
        design {
            switch -exact -- $units {
                US { set Ec [expr 1802.5*sqrt($fc)] }
                SI { set Ec [expr 4733.0*sqrt($fc)] }
                default { error "ERROR: units not recgonized" }
            }
        }
        default {
            error "ERROR: Ec_type not recgonized -- $Ec_type"
        }
    }

    # ############### Strain at Peak Stress ###############
    switch -exact -- $ec_type {
        ChangMander {
            switch -exact -- $units {
                US { set ec [expr pow($fc*6.89476,0.25)/1150.0] }
                SI { set ec [expr pow($fc,0.25)/1150.0] }
                default { error "ERROR: units not recgonized" }
            }
        }
        default {
            error "ERROR: ec_type not recgonized -- $ec_type"
        }
    }


    # ############### Confinement Model ###############
    if { $fl2 == 0.0 } {
        set fcc $fc
    } elseif { $fl2 == $fl1 } {
        set fl $fl1
        set fcc [expr $fc*(-1.254 + 2.254*sqrt(1 + 7.94*$fl/$fc) - 2*$fl/$fc)]
    } else {
        set xbar [expr ($fl1+$fl2)/(2.0*$fc)]
        set r    [expr ($fl1/$fl2)]
        set A    [expr 6.8886-(0.6069+17.275*$r)*exp(-4.989*$r)]
        set B    [expr 4.5/((5/$A)*(0.9849-0.6306*exp(-3.8939*$r))-0.1)-5]
        set K    [expr 1+$A*$xbar*(0.1+0.9/(1+$B*$xbar))]
        set fcc  [expr $K*$fc]
    }
	set ecc        [expr $ec*(1 + 5*($fcc/$fc - 1))]


    # ############### Tension Properties ###############
    switch -exact -- $tension_type {
        ChangMander {
            switch -exact -- $units {
                US { set ft [expr (0.5*sqrt($fc*6.89476))/6.89476] }
                SI { set ft [expr 0.5*sqrt($fc)] }
                default { error "ERROR: units not recgonized" }
            }
            set et         [expr 1.23*$ft/$Ec]
            set rp         4.0
            set xp_cr      4.0
        }
        none {
            set ft         0.0
            set et         0.0
            set rp         4.0
            set xp_cr      4.0
        }
        default {
            error "ERROR: tension_type not recgonized -- $tension_type"
        }
    }


    # ############### "rn_pre" factor ###############
    switch -exact -- $rn_pre_type {
        Popovics {
            set n [expr $Ec*$ecc/$fcc]
            set rn_pre [expr $n/($n-1)]
        }
        ChangMander {
            switch -exact -- $units {
                US { set rn_pre  [expr $fc*6.89476/5.2 - 1.9] }
                SI { set rn_pre  [expr $fc/5.2 - 1.9] }
                default { error "ERROR: units not recgonized" }
            }
        }
        default {
            if { [string is double -strict $rn_pre_type ] } {
                set rn_pre $rn_pre_type
            } else {
                error "ERROR: rn_pre_type not recgonized -- $rn_pre_type"
            }
        }
    }


    # ############### "rn_post" factor ###############
    switch -exact -- $rn_post_type {
        Popovics {
            set n [expr $Ec*$ecc/$fcc]
            set rn_post [expr $n/($n-1)]
        }
        ChangMander {
            switch -exact -- $units {
                US { set rn_post  [expr $fc*6.89476/5.2 - 1.9] }
                SI { set rn_post  [expr $fc/5.2 - 1.9] }
                default { error "ERROR: units not recgonized" }
            }
        }
        default {
            if { [string is double -strict $rn_post_type ] } {
                set rn_post $rn_post_type
            } else {
                error "ERROR: rn_post_type not recgonized -- $rn_post_type"
            }
        }
    }


	# ############### Define Material ###############
    eval uniaxialMaterial changManderConcrete01 $matTag -$fcc -$ecc $Ec \
        $rn_pre $rn_post $ft $et $rp $xp_cr $extraArgs
    # uniaxialMaterial Concrete04 $matTag -$fcc -$ecc -1.0 $Ec
    # uniaxialMaterial Concrete01 $matTag -$fcc -$ecc [expr -0.85*$fcc] [expr -5*$ecc]
}
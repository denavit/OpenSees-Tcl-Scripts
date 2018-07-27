proc OpenSeesComposite::srcSection { secID startMatID nf1 nf2 units B H fc d tw bf tf Fy Fu Es reinf args} {
    # ###################################################################
    # srcSection $secID $startMatID $nf1 $nf2 $units $B $H $fc $d $tw $bf $tf $Fy $Fu $Es $reinf ...
    # ###################################################################
    # tcl procedure for creating a steel reinforced concrete fiber section
    #
    # input parameters:
    # secID - section ID number
    # startMatID - starting number for the material that will be defined
    # nf1 = number of fibers along the primary bending axis (strong axis for 3d)
    # nf2 = number of fibers along the secondary bending axis
    #    - strong = creates a 2d section for strong axis bending
    #    - weak   = creates a 2d section for weak axis bending
    # units - unit system
    #    US = United States customary units (i.e., kips, inches, ksi)
    #    SI = International System of Units (i.e., N, mm, MPa)
    # B = column width
    # H = column depth
    # fc = concrete compressive strength
    # d = nominal depth of the steel section
    # tw = web thickness of the steel section
    # bf = flange width of the steel section
    # tf = flange thickness of the steel section
    # Fy = yield strength of the steel section
    # Fu = ultimate strength of the steel section
    # Es = modulus of elasticity of the steel section
    # reinf = definition of the reinforcing configuration
    # Added Elastic Stiffness
    #    - "-AddedElastic $EA $EI" for 2D sections
    #    - "-AddedElastic $EA $EIz $EIy $GJ" for 3D sections

    # ########### Set Constants and Default Values ###########
    set pi  [expr 2*asin(1.0)]
    set numResidualStressDiv 10

    set concMaterialType  ProposedForBehavior
    set steelMaterialType ProposedForBehavior
    set reinfMaterialType ProposedForBehavior
    set AddedElastic no
    set GJ max_steel_or_concrete_only
    set WideFlangeResidualStressParameter 1.0
    set DefineSteelFibers true
    set DefineConcreteFibers true
    set DefineReinforcingFibers true

    # ########### Check Required Input ###########
    set B   [expr double($B)]
    set H   [expr double($H)]
    set fc  [expr double($fc)]
    set d   [expr double($d)]
    set tw  [expr double($tw)]
    set bf  [expr double($bf)]
    set tf  [expr double($tf)]
    set Fy  [expr double($Fy)]
    if { $Fu != "calc" } { set Fu  [expr double($Fu)] }
    if { $Es != "calc" } { set Es  [expr double($Es)] }

    set nf1 [expr int($nf1)]
    if { $nf1 <= 0 } {
        error "Error - srcSection: the number of fibers (nf1) should be positive"
    }

    if { [string compare -nocase $nf2 "strong"] == 0 } {
        set bendingType 2dStrong
    } elseif { [string compare -nocase $nf2 "weak"] == 0 } {
        set bendingType 2dWeak
    } else {
        set bendingType 3d
        set nf2 [expr int($nf2)]
        if { $nf2 <= 0 } {
            error "Error - srcSection: the number of fibers (nf2) should be positive"
        }
    }

    if { $d <= 0.0 || $tw <= 0.0 || $bf <= 0.0 || $tf <= 0.0 } {
        error "Error - srcSection: Steel section dimensions should be input as a posititve values"
    }
    if { $B <= $bf || $H <= $d } {
        error "Error - srcSection: Gross section dimensions should be greater than those of the steel section"
    }
    if { $Fy <= 0.0 } {
        error "Error - srcSection: Steel yield strength should be input as a posititve values"
    }
    if { $Fu <= $Fy && $Fu != "calc" } {
        error "Error - srcSection: Steel ultimate strength should greater than Fy or calc"
    }
    if { $Es <= 0.0 && $Es != "calc" } {
        error "Error - srcSection: Steel elastic modulus should be input as a posititve values or calc"
    }
    if { $fc <= 0.0 } {
        error "Error - srcSection: Concrete compressive strength should be input as a posititve value"
    }


    # ########### Read Optional Input ###########
    for { set i 0 } { $i < [llength $args] } { incr i } {
        set param [lindex $args $i]
        if { $param == "-ConcreteMaterialType" } {
            set concMaterialType [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-SteelMaterialType" } {
            set steelMaterialType [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-WideFlangeResidualStressParameter" } {
            set WideFlangeResidualStressParameter [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-ReinforcementMaterialType" } {
            set reinfMaterialType [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-GJ" } {
            set GJ [lindex $args [expr $i+1]]
            incr i 1
            continue
        }
        if { $param == "-AddedElastic" } {
            set AddedElastic yes
            if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {
                incr i
                set AddedElasticEA [lindex $args $i]
                incr i
                set AddedElasticEI [lindex $args $i]
            } elseif { $bendingType == "3d" } {
                incr i
                set AddedElasticEA [lindex $args $i]
                incr i
                set AddedElasticEIz [lindex $args $i]
                incr i
                set AddedElasticEIy [lindex $args $i]
                incr i
                set AddedElasticGJ [lindex $args $i]
            }
            continue
        }
        if { $param == "-noSteel" } {
            set DefineSteelFibers false
            incr i 1
            continue
        }
        if { $param == "-noRC" } {
            set DefineConcreteFibers false
            set DefineReinforcingFibers false
            incr i 1
            continue
        }
        error "Error - srcSection: unknown optional parameter: $param"
    }


    # ########### Compute Fu and Es if necessary ###########
	if { $Fu == "calc" } {
      set Fu [defaultValue_Fu $Fy $units]
    }
    if { $Es == "calc" } {
      set Es [defaultValue_Es $units]
    }


    # ########### Compute Confining Pressure ###########
    if { [string compare -nocase $reinf "none"] == 0 } {
        set hasReinf false
        set coverH  0.0
        set coverB  0.0
        set flmedz  0.0
        set flmedy  0.0
        set longReinf_y  [list]
        set longReinf_z  [list]
        set longReinf_A  [list]
    } else {
        parseReinf $reinf $bendingType $B $H $d $bf $units
    }
    set flhighz $flmedz
    set flhighy [expr $flmedy + $tf*$tf*$Fy/(3*pow(($bf-$tw)/2,2))]

    # ########### Set Additional Section Dimensions ###########
    set dw [expr $d - 2 * $tf]
    set d1 [expr $dw/2]
    set d2 [expr $d/2]
    set b1 [expr $tw/2]
    set b2 [expr $bf/2]
    set H1 [expr $H/2]
    set H2 [expr $H1-$coverH]
    set B1 [expr $B/2]
    set B2 [expr $B1-$coverB]
    # Shape of parabola in between flanges
    set za [expr $b2-0.25*$dw]
    if { $za < $b1 } { set za $b1 }
    set zb $b2

    
    # ########### Compute GJ if necessary ###########
    set Gs  [expr $Es/(2*(1+0.3))]
    set Js  [expr (2*$bf*pow($tf,3) + pow($tw,2)*($d-2*$tf))/3.0]

    switch -exact -- $units {
      US { set Ec [expr 1802.5*sqrt($fc)] }
      SI { set Ec [expr 4733.0*sqrt($fc)] }
      default { error "ERROR: units not recgonized" }
    }
    set Gc  [expr $Ec/(2*(1+0.2))]
    set beta  [expr 1.0/3.0*(1-192.0/pow($pi,5)*$B/$H*tanh($pi*$H/(2.0*$B)))]      
    set Jc  [expr $beta*$H*pow($B,3)]
    
    if { $GJ == "steelonly" } {
      set GJ [expr $Gs*$Js]
    } elseif { $GJ == "concreteonly" } {
      set GJ [expr $Gc*$Jc]
    } elseif { $GJ == "max_steel_or_concrete_only" } {
      set GJ [expr max($Gs*$Js,$Gc*$Jc)]
    }

    
    # ########### Define Section by calling itself with secID = noSection ###########
    if { [string compare -nocase $secID "noSection"] != 0 } {
      section Fiber $secID -GJ $GJ {
          eval srcSection noSection $startMatID $nf1 $nf2 $units $B $H $fc $d $tw $bf $tf $Fy $Fu $Es [list $reinf] $args
      }
      return
    }


    # ########### Set Concrete Materials ###########
    if { $DefineConcreteFibers } {
        set coverConcID [expr $startMatID]
        set medConfinedConcID  [expr $startMatID+1]
        set highConfinedConcID [expr $startMatID+2]
        switch -exact -- $concMaterialType {
            ProposedForBehavior {
                changManderConcreteMaterial $coverConcID $fc $units \
                    -cover -rn_pre ChangMander -rn_post 0.75
                if { $hasReinf } {
                    changManderConcreteMaterial $medConfinedConcID $fc $units \
                        -triaxial $flmedz $flmedy -rn_pre ChangMander -rn_post 0.75
                } else {
                    set medConfinedConcID $coverConcID
                }
                changManderConcreteMaterial $highConfinedConcID $fc $units \
                    -triaxial $flhighz $flhighy -rn_pre ChangMander -rn_post 0.75
            }
            ProposedForDesign {
                changManderConcreteMaterial $coverConcID $fc $units \
                    -cover -r Popovics -tension none
                if { $hasReinf } {
                    changManderConcreteMaterial $medConfinedConcID $fc $units \
                        -triaxial $flmedz $flmedy -r Popovics -tension none
                } else {
                    set medConfinedConcID $coverConcID
                }
                changManderConcreteMaterial $highConfinedConcID $fc $units \
                    -triaxial $flhighz $flhighy -r Popovics -tension none
            }
            ProposedForDesign_EI {
                changManderConcreteMaterial $coverConcID $fc $units \
                    -cover -r Popovics -tension Popovics
                if { $hasReinf } {
                    changManderConcreteMaterial $medConfinedConcID $fc $units \
                        -triaxial $flmedz $flmedy -r Popovics -tension Popovics
                } else {
                    set medConfinedConcID $coverConcID
                }
                changManderConcreteMaterial $highConfinedConcID $fc $units \
                    -triaxial $flhighz $flhighy -r Popovics -tension Popovics
            }
            Elastic {
                switch -exact -- $units {
                    US { set Ec [expr 1802.5*sqrt($fc)] }
                    SI { set Ec [expr 4733.0*sqrt($fc)] }
                    default { error "ERROR: units not recgonized" }
                }
                uniaxialMaterial Elastic $coverConcID $Ec
                set medConfinedConcID $coverConcID
                set highConfinedConcID $coverConcID
            }
            ElasticNoTension {
                switch -exact -- $units {
                    US { set Ec [expr 1802.5*sqrt($fc)] }
                    SI { set Ec [expr 4733.0*sqrt($fc)] }
                    default { error "ERROR: units not recgonized" }
                }
                uniaxialMaterial ENT $coverConcID $Ec
                set medConfinedConcID $coverConcID
                set highConfinedConcID $coverConcID
            }
            default {
                error "ERROR: srcSection: unknown concrete material type: $concMaterialType"
            }
        }


        # ########### Define Concrete Fibers: 2d Strong ###########
        if { $bendingType == "2dStrong" } {

            # Define cover concrete
            if { $coverB > 0.0 } {
                set nfdi [expr int(ceil(($H)*($nf1/$H)))]
                patchRect2d $coverConcID $nfdi [expr 2*$coverB] -$H1 $H1
            }
            if { $coverH > 0.0 } {
                set nfdi [expr int(ceil(($coverH)*($nf1/$H)))]
                patchRect2d $coverConcID $nfdi [expr $B-2*$coverB] -$H1 -$H2
                patchRect2d $coverConcID $nfdi [expr $B-2*$coverB]  $H2  $H1
            }

            # Define medium confined concrete
            set nfdi [expr int(ceil(($H2-$d2)*($nf1/$H)))]
            patchRect2d $medConfinedConcID $nfdi [expr $B-2*$coverB] -$H2 -$d2
            patchRect2d $medConfinedConcID $nfdi [expr $B-2*$coverB]  $d2  $H2
            set nfdi [expr int(ceil(($tf)*($nf1/$H)))]
            patchRect2d $medConfinedConcID $nfdi [expr $B-2*$coverB-$bf] -$d2 -$d1
            patchRect2d $medConfinedConcID $nfdi [expr $B-2*$coverB-$bf]  $d1  $d2

            # Define concrete between the webs
            set nfdw [expr int(ceil(($dw)*($nf1/$H)))]
            set pa [expr ($zb-$za)/($d1*$d1)]
            set pc $za
            for { set i 1 } { $i <= $nfdw } { incr i } {
                set di1  [expr -$d1 + ($i-1)*(2*$d1/$nfdw)]
                set di2  [expr -$d1 + ($i  )*(2*$d1/$nfdw)]
                set bh   [expr $pa*(($di1*$di1+$di1*$di2+$di2*$di2)/3.0)+$pc]
                patchRect2d $highConfinedConcID 1 [expr 2*($bh-$b1)] $di1 $di2
                patchRect2d $medConfinedConcID  1 [expr 2*($B2-$bh)] $di1 $di2
            }

        # ########### Define Concrte Fibers: 2d Weak ###########
        } elseif { $bendingType == "2dWeak" } {

            # Define cover concrete
            if { $coverB > 0.0 } {
                set nfbi [expr int(ceil(($coverB)*($nf1/$B)))]
                patchRect2d $coverConcID $nfbi $H -$B1 -$B2
                patchRect2d $coverConcID $nfbi $H  $B2  $B1
            }
            if { $coverH > 0.0 } {
                set nfbi [expr int(ceil(($B-2*$coverB)*($nf1/$B)))]
                patchRect2d $coverConcID $nfbi [expr 2*$coverH] -$B2 $B2
            }

            # Define medium confined concrete
            set nfbi [expr int(ceil(($B2-$b2)*($nf1/$B)))]
            patchRect2d $medConfinedConcID $nfbi [expr $H-2*$coverH]  -$B2 -$b2
            patchRect2d $medConfinedConcID $nfbi [expr $H-2*$coverH]   $b2  $B2
            set nfbi [expr int(ceil((2*$b2)*($nf1/$B)))]
            patchRect2d $medConfinedConcID $nfbi [expr 2*($H2-$d2)]  -$b2  $b2

            # Define concrete between the webs
            set pa [expr ($zb-$za)/($d1*$d1)]
            set pc $za
            set nfbi [expr int(ceil(($za-$b1)*($nf1/$B)))]
            if { $za > $b1 } {
                patchRect2d $highConfinedConcID $nfbi $dw -$za -$b1
                patchRect2d $highConfinedConcID $nfbi $dw  $b1  $za
            }
            set nfp [expr int(ceil(($zb-$za)*($nf1/$B)))]
            for { set i 1 } { $i <= $nfp } { incr i } {
                set di1  [expr $za + ($i-1)*(($zb-$za)/$nfp)]
                set di2  [expr $za + ($i  )*(($zb-$za)/$nfp)]
                set wmc  [expr (4.0/(3.0*sqrt($pa)*($di1-$di2)))*(pow($di1-$pc,1.5)-pow($di2-$pc,1.5))]
                patchRect2d $highConfinedConcID 1 [expr $dw-$wmc] -$di2 -$di1
                patchRect2d $highConfinedConcID 1 [expr $dw-$wmc]  $di1  $di2
                patchRect2d $medConfinedConcID  1 $wmc            -$di2 -$di1
                patchRect2d $medConfinedConcID  1 $wmc             $di1  $di2
            }
            if { $zb > $b2 } {
                patchRect2d $medConfinedConcID  1 $dw -$b2 -$zb
                patchRect2d $medConfinedConcID  1 $dw  $zb  $b2
            }

        # ########### Define Concrete Fibers: 3d ###########
        } elseif { $bendingType == "3d" } {

            # Define cover concrete
            if { $coverB > 0.0 } {
                set nfdi [expr int(ceil(($H)*($nf1/$H)))]
                set nfbi [expr int(ceil(($coverB)*($nf1/$B)))]
                patch quad $coverConcID $nfdi $nfbi $H1 -$B2 -$H1 -$B2 -$H1 -$B1 $H1 -$B1
                patch quad $coverConcID $nfdi $nfbi $H1  $B1 -$H1  $B1 -$H1  $B2 $H1  $B2
            }
            if { $coverH > 0.0 } {
                set nfdi [expr int(ceil(($coverH)*($nf1/$H)))]
                set nfbi [expr int(ceil(($B-2*$coverB)*($nf2/$B)))]
                patch quad $coverConcID $nfdi $nfbi  $H1 $B2  $H2 $B2  $H2 -$B2  $H1 -$B2
                patch quad $coverConcID $nfdi $nfbi -$H2 $B2 -$H1 $B2 -$H1 -$B2 -$H2 -$B2
            }

            # Define medium confined concrete
            set nfdi [expr int(ceil(($H2-$d2)*($nf1/$H)))]
            set nfbi [expr int(ceil(($B-2*$coverB)*($nf2/$B)))]
            patch quad $medConfinedConcID $nfdi $nfbi  $H2 $B2  $d2 $B2  $d2 -$B2  $H2 -$B2
            patch quad $medConfinedConcID $nfdi $nfbi -$d2 $B2 -$H2 $B2 -$H2 -$B2 -$d2 -$B2
            set nfdi [expr int(ceil(($tf)*($nf1/$H)))]
            set nfbi [expr int(ceil(($B2-$b2)*($nf2/$B)))]
            patch quad $medConfinedConcID $nfdi $nfbi  $d2  $B2  $d1  $B2  $d1  $b2  $d2  $b2
            patch quad $medConfinedConcID $nfdi $nfbi -$d1  $B2 -$d2  $B2 -$d2  $b2 -$d1  $b2
            patch quad $medConfinedConcID $nfdi $nfbi  $d2 -$b2  $d1 -$b2  $d1 -$B2  $d2 -$B2
            patch quad $medConfinedConcID $nfdi $nfbi -$d1 -$b2 -$d2 -$b2 -$d2 -$B2 -$d1 -$B2

            # Define concrete between the webs
            set nfdw [expr int(ceil(($dw)*($nf1/$H)))]
            set pa [expr ($zb-$za)/($d1*$d1)]
            set pc $za
            for { set i 1 } { $i <= $nfdw } { incr i } {
                set di1  [expr -$d1 + ($i-1)*(2*$d1/$nfdw)]
                set di2  [expr -$d1 + ($i  )*(2*$d1/$nfdw)]
                set bh   [expr $pa*(($di1*$di1+$di1*$di2+$di2*$di2)/3.0)+$pc]
                set nfbh [expr int(ceil(($bh-$b1)*($nf2/$B)))]
                set nfbm [expr int(ceil(($B2-$bh)*($nf2/$B)))]
                patch quad $highConfinedConcID 1 $nfbh  $di2  $bh  $di1  $bh  $di1  $b1  $di2  $b1
                patch quad $medConfinedConcID  1 $nfbm  $di2  $B2  $di1  $B2  $di1  $bh  $di2  $bh
                patch quad $highConfinedConcID 1 $nfbh  $di2 -$b1  $di1 -$b1  $di1 -$bh  $di2 -$bh
                patch quad $medConfinedConcID  1 $nfbm  $di2 -$bh  $di1 -$bh  $di1 -$B2  $di2 -$B2
            }

        } else {
            error "Error - srcSection: unknown bendingAxis"
        }
    }


    # ########### Define Steel Section ###########
    if { $DefineSteelFibers } {    
        if { $bendingType == "2dStrong" } {
            set nf1i [expr ($d)*($nf1/$H)]
            set nf2i strong
        } elseif { $bendingType == "2dWeak" } {
            set nf1i [expr ($bf)*($nf1/$B)]
            set nf2i weak
        } elseif { $bendingType == "3d" } {
            set nf1i [expr ($d)*($nf1/$H)]
            set nf2i [expr ($bf)*($nf2/$B)]
        } else {
            error "Error - srcSection: unknown bendingAxis"
        }
        set residualStress [expr -0.3*$Fy*$WideFlangeResidualStressParameter]
        switch -exact -- $steelMaterialType {
            Shen {
                wfSection noSection $nf1i $nf2i $d $tw $bf $tf \
                    -ShenSteel [expr $startMatID+3] $Es $Fy $Fu [expr 120*$Fy/$Es] $units \
                    -Lehigh $residualStress $numResidualStressDiv
            }
            ElasticPP {
                wfSection noSection $nf1i $nf2i $d $tw $bf $tf \
                    -ElasticPP [expr $startMatID+3] $Es $Fy \
                    -Lehigh $residualStress $numResidualStressDiv
            }
            ElasticSmallStiffness {
                wfSection noSection $nf1i $nf2i $d $tw $bf $tf \
                    -ElasticSmallStiffness [expr $startMatID+3] $Es $Fy \
                    -Lehigh $residualStress $numResidualStressDiv
            }
            Elastic {
                wfSection noSection $nf1i $nf2i $d $tw $bf $tf \
                    -Elastic [expr $startMatID+3] $Es
            }
            default {
                error "ERROR: srcSection: unknown steel material type: $steelMaterialType"
            }
        }
    }

    if { $hasReinf && $DefineReinforcingFibers } {
        # ########### Set Longitudinal Reinforcing Steel Materials ###########
        set reinfSteelID [expr $startMatID+$numResidualStressDiv+4]
        switch -exact -- $reinfMaterialType {
            ProposedForBehavior {
                set longReinfey [expr $longReinfFy/$longReinfEs]
                set longReinfeu [expr 120*$longReinfFy/$longReinfEs]

                #set localBucklingStrain [expr (55-102*sqrt($longReinfey)*$longReinfS/$longReinfDb)*$longReinfey]
                set localBucklingStrain $longReinfey
                set Ksft [expr $longReinfEs/100.0]
                set frs  0.2
                puts "localBucklingStrain $localBucklingStrain"

                shenSteelMaterial $reinfSteelID $longReinfEs $longReinfFy $longReinfFu $longReinfeu $units \
                    -type hotRolled \
                    -localBuckling -$localBucklingStrain -$Ksft $frs Fy \
                    -localBucklingDegradationEp    2.0 0.05 \
                    -localBucklingDegradationKappa 2.0 0.05
            }
            ElasticPP {
                uniaxialMaterial ElasticPP $reinfSteelID $longReinfEs [expr double($longReinfFy)/double($longReinfEs)]
            }
            ElasticSmallStiffness {
                uniaxialMaterial multiSurfaceKinematicHardening $reinfSteelID -Direct $longReinfEs 0.0 $longReinfFy [expr double($longReinfEs)/1000.0]
            }
            Elastic {
                uniaxialMaterial Elastic $reinfSteelID $longReinfEs
            }
            default {
                error "ERROR: srcSection: unknown reinforcing material type: $reinfMaterialType"
            }
        }

        # ########### Define Reinforcing Steel Fibers ###########
        for { set i 0 } { $i < [llength $longReinf_A] } { incr i } {
            set yLoc [lindex $longReinf_y $i]
            set zLoc [lindex $longReinf_z $i]
            set A    [lindex $longReinf_A $i]

            fiber $yLoc $zLoc [expr -1*$A] $medConfinedConcID
            fiber $yLoc $zLoc $A $reinfSteelID
        }
    }

    # ########### Add elastic stiffness if necessary ###########
    if { $AddedElastic == "yes" } {
        set ElasticE 1.0;
        set matID [expr $startMatID+$numResidualStressDiv+5]
        incr currentMatTag
        uniaxialMaterial Elastic $matID $ElasticE
        if { $bendingType == "2dStrong" || $bendingType == "2dWeak" } {
            twoFiberSection noSection $matID \
                [expr $AddedElasticEA/$ElasticE] \
                [expr $AddedElasticEI/$ElasticE]
        } elseif { $bendingType == "3d" } {
            fourFiberSectionGJ noSection $matID \
                [expr $AddedElasticEA/$ElasticE] \
                [expr $AddedElasticEIy/$ElasticE] \
                [expr $AddedElasticEIz/$ElasticE] \
                $AddedElasticGJ
        }
    }
}


proc OpenSeesComposite::parseReinf { reinf bendingType B H d bf units } {

    # parses the argument "reinf" and provides the main function with definitions of the following variables
    #   - hasReinf
    #   - coverH
    #   - coverB
    #   - flmedz
    #   - flmedy
    #   - longReinf_y
    #   - longReinf_z
    #   - longReinf_A
    #   - longReinfEs
    #   - longReinfFy
    #   - longReinfFu


    set pi  [expr 2*asin(1.0)]
    set reinfConfig [lindex $reinf 0]
    
    if { $reinfConfig == "none" } {
        set hasReinf false

    } elseif { [regexp -nocase "^(\[0-9]+)\[xz]\-(\[0-9]+)\y\-?(\[a-z0-9]*)$" $reinfConfig scratch nBarZ nBarY option] } {

        set db       [expr double([lindex $reinf 1])]
        set Fylr     [expr double([lindex $reinf 2])]
        if { [lindex $reinf 3] == "calc" } {
            set Fulr [defaultValue_Fu $Fylr $units]
        } else {
            set Fulr [expr double([lindex $reinf 3])]
        }
        if { [lindex $reinf 4] == "calc" } {
            set Eslr [defaultValue_Es $units]
        } else {
            set Eslr [expr double([lindex $reinf 4])]
        }
        set dbTies   [expr double([lindex $reinf 5])]
        set s        [expr double([lindex $reinf 6])]
        set Fytr     [expr double([lindex $reinf 7])]
        set cover    [expr double([lindex $reinf 8])]


        set Ab           [expr $pi*$db*$db/4]
        set Abt          [expr $pi*$dbTies*$dbTies/4]
        set hasReinf     true
        set coverH       [expr $cover+0.5*$dbTies]
        set coverB       [expr $cover+0.5*$dbTies]
        set cornerZloc   [expr $B/2 - $cover - $dbTies - $db/2]
        set cornerYloc   [expr $H/2 - $cover - $dbTies - $db/2]
        set Hc           [expr $H-2*$coverH]
        set Bc           [expr $B-2*$coverB]
        set Ac           [expr $Hc*$Bc]
        set longReinfEs  $Eslr
        set longReinfFy  $Fylr
        set longReinfFu  $Fulr

        if { $option == "" || [string compare -nocase $option "corner"] == 0 } {
            if { $nBarZ < 2 || $nBarY < 2 } {
                error "ERROR - parseReinf - need at least 2 rebar in each direction"
            }
            if { [expr $nBarZ%2] == 1 || [expr $nBarY%2] == 1 } {
                error "ERROR - parseReinf - rebar should be specified in even numbers"
            }
            switch -exact -- $units {
                US { set spacing0 1.5 }             
                SI { set spacing0 38.1 }
                default { error "ERROR - parseReinf: units not recgonized" }
            }
            if { [expr 1.5*$db] < $spacing0 } {
                set spacing [expr 1.5*$db]
            } else {
                set spacing $spacing0
            }
            set spacing [expr $spacing + $db]
            
            if { $bendingType == "2dStrong" } {
                set longReinf_z     [list 0.0]
                set longReinf_y     [list $cornerYloc]
                set longReinf_y_neg [expr [expr -1*$cornerYloc]]
                set longReinf_A     [list [expr $nBarZ*$Ab]]
                for { set i 1 } { $i <= [expr $nBarY/2 - 1] } { incr i } {
                    lappend longReinf_z     0.0
                    lappend longReinf_y     [expr  $cornerYloc - $i*$spacing]
                    lappend longReinf_y_neg [expr -$cornerYloc + $i*$spacing]
                    lappend longReinf_A     [expr  2*$Ab]
                }
                eval lappend longReinf_z $longReinf_z
                eval lappend longReinf_y $longReinf_y_neg
                eval lappend longReinf_A $longReinf_A
            } elseif { $bendingType == "2dWeak" } {
                set longReinf_z     [list 0.0]
                set longReinf_y     [list $cornerZloc]
                set longReinf_y_neg [expr [expr -1*$cornerZloc]]
                set longReinf_A     [list [expr $nBarY*$Ab]]
                for { set i 1 } { $i <= [expr $nBarZ/2 - 1] } { incr i } {
                    lappend longReinf_z     0.0
                    lappend longReinf_y     [expr  $cornerZloc - $i*$spacing]
                    lappend longReinf_y_neg [expr -$cornerZloc + $i*$spacing]
                    lappend longReinf_A     [expr  2*$Ab]
                }
                eval lappend longReinf_z $longReinf_z
                eval lappend longReinf_y $longReinf_y_neg
                eval lappend longReinf_A $longReinf_A
            } elseif { $bendingType == "3d" } {
                set longReinf_z     [list $cornerZloc]
                set longReinf_z_neg [list [expr -1*$cornerZloc]]
                set longReinf_y     [list $cornerYloc]
                set longReinf_y_neg [expr [expr -1*$cornerYloc]]
                set longReinf_A     [list $Ab]
                for { set i 1 } { $i <= [expr $nBarZ/2 - 1] } { incr i } {
                    lappend longReinf_z     [expr  $cornerZloc - $i*$spacing]
                    lappend longReinf_z_neg [expr -$cornerZloc + $i*$spacing]
                    lappend longReinf_y     [expr  $cornerYloc]
                    lappend longReinf_y_neg [expr -$cornerYloc]
                    lappend longReinf_A     [expr  $Ab]
                }
                for { set i 1 } { $i <= [expr $nBarY/2 - 1] } { incr i } {
                    lappend longReinf_z     [expr  $cornerZloc]
                    lappend longReinf_z_neg [expr -$cornerZloc]
                    lappend longReinf_y     [expr  $cornerYloc - $i*$spacing]
                    lappend longReinf_y_neg [expr -$cornerYloc + $i*$spacing]
                    lappend longReinf_A     [expr  $Ab]
                }
                eval lappend longReinf_z $longReinf_z_neg $longReinf_z_neg $longReinf_z
                eval lappend longReinf_y $longReinf_y $longReinf_y_neg $longReinf_y_neg
                eval lappend longReinf_A $longReinf_A $longReinf_A $longReinf_A
            } else {
                error "Error - srcSection: unknown bendingAxis"
            }

            # Define clearDistances
            set beamClearanceZ [expr 2*$cornerZloc - ($nBarZ-2)*$spacing - $db]
            set beamClearanceY [expr 2*$cornerYloc - ($nBarY-2)*$spacing - $db]
            if { $beamClearanceZ <= 0 || $beamClearanceY <= 0 } {
                error "Error - parseReinf - overlap of reinforcing"
            }
            set clearDistances [list $beamClearanceZ $beamClearanceZ $beamClearanceY $beamClearanceY]
            if { $nBarZ > 2 || $nBarY > 2 } {
                for { set i 1 } { $i <= [expr 2*($nBarZ-2)+2*($nBarY-2)] } { incr i } {
                    set clearDistances [lappend clearDistances [expr $spacing-$db]]
                }                    
            }

        } elseif { [string compare -nocase $option "even"] == 0 } {
            if { $nBarZ < 2 || $nBarY < 2 } {
                error "ERROR - parseReinf - need at least 2 rebar in each direction"
            }
            set spacingZ [expr 2*$cornerZloc/($nBarZ-1)]
            set spacingY [expr 2*$cornerYloc/($nBarY-1)]
            if { $spacingZ <= $db || $spacingY <= $db } {
                error "Error - parseReinf - overlap of reinforcing"
            }

            if { $bendingType == "2dStrong" } {
                set longReinf_z     [list 0.0]
                set longReinf_y     [list $cornerYloc]
                set longReinf_A     [list [expr $nBarZ*$Ab]]
                for { set i 1 } { $i <= [expr $nBarY - 2] } { incr i } {
                    lappend longReinf_z  0.0
                    lappend longReinf_y  [expr $cornerYloc - $i*$spacingY]
                    lappend longReinf_A  [expr $Ab]
                }
                lappend longReinf_z  0.0
                lappend longReinf_y  [expr -1*$cornerYloc]
                lappend longReinf_A  [expr $nBarZ*$Ab]
            } elseif { $bendingType == "2dWeak" } {
                set longReinf_z     [list 0.0]
                set longReinf_y     [list $cornerZloc]
                set longReinf_A     [list [expr $nBarY*$Ab]]
                for { set i 1 } { $i <= [expr $nBarZ - 2] } { incr i } {
                    lappend longReinf_z  0.0
                    lappend longReinf_y  [expr $cornerZloc - $i*$spacingZ]
                    lappend longReinf_A  [expr $Ab]
                }
                lappend longReinf_z  0.0
                lappend longReinf_y  [expr -1*$cornerZloc]
                lappend longReinf_A  [expr $nBarY*$Ab]
            } elseif { $bendingType == "3d" } {
                set longReinf_z     [list $cornerZloc]
                set longReinf_z_neg [list [expr -1*$cornerZloc]]
                set longReinf_y     [list $cornerYloc]
                set longReinf_y_neg [expr [expr -1*$cornerYloc]]
                set longReinf_A     [list $Ab]
                for { set i 1 } { $i <= [expr $nBarZ - 2] } { incr i } {
                    lappend longReinf_z     [expr -$cornerZloc + $i*$spacingZ]
                    lappend longReinf_z_neg [expr  $cornerZloc - $i*$spacingZ]
                    lappend longReinf_y     [expr  $cornerYloc]
                    lappend longReinf_y_neg [expr -$cornerYloc]
                    lappend longReinf_A     [expr  $Ab]
                }
                for { set i 0 } { $i <= [expr $nBarY - 1] } { incr i } {
                    lappend longReinf_z     [expr  $cornerZloc]
                    lappend longReinf_z_neg [expr -$cornerZloc]
                    lappend longReinf_y     [expr  $cornerYloc - $i*$spacingY]
                    lappend longReinf_y_neg [expr -$cornerYloc + $i*$spacingY]
                    lappend longReinf_A     [expr  $Ab]
                }
                eval lappend longReinf_z $longReinf_z_neg
                eval lappend longReinf_y $longReinf_y_neg
                eval lappend longReinf_A $longReinf_A

            } else {
                error "Error - srcSection: unknown bendingAxis"
            }

            # Define clearDistances
            set clearDistances [list]
            for { set i 1 } { $i <= [expr 2*($nBarZ-1)] } { incr i } {
                set clearDistances [lappend clearDistances [expr $spacingZ-$db]]
            }
            for { set i 1 } { $i <= [expr 2*($nBarY-1)] } { incr i } {
                set clearDistances [lappend clearDistances [expr $spacingY-$db]]
            }
            
        } else {
            error "ERROR - parseReinf - unknown option"

        }

        # Compute Total Area of Longitudinal Reinforcement, Asrt
        set Asrt 0.0
        for { set i 0 } { $i < [llength $longReinf_A] } { incr i } {
            set Asrt [expr $Asrt + [lindex $longReinf_A $i]]
        }

        # Compute Area of Effectively Confined Conrete Core, Ae
        set Ae $Ac
        for { set i 0 } { $i < [llength $clearDistances] } { incr i } {
            set wi [lindex $clearDistances $i]
            set Ae [expr $Ae - $wi*$wi/6.0]
        }
        set sprime  [expr $s-$dbTies]
        set Ae      [expr $Ae*(1-$sprime/(2*$Bc))*(1-$sprime/(2*$Hc))]

        # Compute Confining Pressure
        if { $dbTies == 0 } {
            set flmedz 0.0
            set flmedy 0.0
        } else {
            set ke [expr $Ae/($Ac-$Asrt)]
            set rhosrtz [expr 2*$Abt/$s/$Hc]
            set rhosrty [expr 2*$Abt/$s/$Bc]
            set flmedz [expr $ke*$rhosrtz*$Fytr]
            set flmedy [expr $ke*$rhosrty*$Fytr]
        }

    } else {
        error "ERROR - parseReinf - unknown reinforcing configuration"
    }


    # Set variables in upper frame
    upvar hasReinf x
    set x $hasReinf
    if { $hasReinf } {
        upvar longReinfEs x
        set x $longReinfEs
        upvar longReinfFy x
        set x $longReinfFy
        upvar longReinfFu x
        set x $longReinfFu
        upvar coverH x
        set x $coverH
        upvar coverB x
        set x $coverB
        upvar flmedz x
        set x $flmedz
        upvar flmedy x
        set x $flmedy
        upvar longReinf_y x
        set x $longReinf_y
        upvar longReinf_z x
        set x $longReinf_z
        upvar longReinf_A x
        set x $longReinf_A
        upvar longReinfDb x
        set x $db
        upvar longReinfS x
        set x $s
    }
}

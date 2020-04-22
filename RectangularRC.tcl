proc RectangularRC { secID startMatID nf1 nf2 units B H fc Ec cover fy fu Es db Ab nBarX nBarY fyt dbt Abt nLegX nLegY s conc_material steel_material} {
    # ###################################################################  
    # RectangularRC $secID $startMatID $nf1 $nf2 $units $B $H $fc $Ec $cover $fy $fu $Es $db $Ab $nBarX $nBarY $fyt $dbt $Abt $nLegX $nLegY $s $conc_material $steel_material
    # ###################################################################
    # tcl procedure for creating a rectangular reinforced concrete fiber section
    #
    # Required input arguments:
    # secID         = section ID number
    # startMatID    = starting ID number for the uniaxial materials that will be defined
    # nf1           = number of fibers along the primary bending axis (X-axis for 3d)
    # nf2           = number of fibers along the secondary bending axis
    #                 - X = creates a 2d section for X-axis bending
    #                 - Y = creates a 2d section for Y-axis bending
    # units         = unit system
    #                 - US = United States customary units (i.e., kips, inches, ksi)
    #                 - SI = International System of Units (i.e., N, mm, MPa)
    # B             = column width
    # H             = column depth
    # fc            = concrete compressive strength
    # Ec            = modulus of elasticity of concrete
    # cover         = concrete cover measured from outside surface of concrete to edge of transverse reinforcing steel
    # fy            = longitudinal reinforcing steel yield stress
    # fu            = longitudinal reinforcing steel ultimate strength
    # Es            = modulus of elasticity of steel
    # db            = diameter of longitudinal reinforcing bar
    # Ab            = cross-sectional of longitudinal reinforcing bar
    # nBarX         = number of longitudinal reinforcing bars along the X-axis
    # nBarY         = number of longitudinal reinforcing bars along the Y-axis
    # fyt           = transverse reinforcing steel yield stress (used for computing confinement only)
    # dbt           = diameter of transverse reinforcing bar
    # Abt           = cross-sectional of transverse reinforcing bar
    # nLegX         = number of stirrup legs oriended in the X-direction
    # nLegY         = number of stirrup legs oriended in the Y-direction
    # s             = spacing of transverse reinfocring bar
    # conc_material = Concrete material type
    #                 - Elastic
    #                 - ElasticNoTension    
    #                 - Concrete04
    # steel_material = Steel material type
    #                 - Elastic
    #                 - ElasticPP    
    #                 - ElasticSmallStiffness
    # 
    
    # ########### Set Constants and Default Values ###########
    set pi  [expr 2*asin(1.0)]

    # ########### Check Required Input ###########
    set B   [expr double($B)]
    set H   [expr double($H)]
    set fc  [expr double($fc)]
    set fyt [expr double($fyt)]
    set fy  [expr double($fy)]
    set fu  [expr double($fu)]
    set Es  [expr double($Es)]

    set nf1 [expr int($nf1)]
    if { $nf1 <= 0 } {
        error "Error - RectangularRC: the number of fibers (nf1) should be positive"
    }

    if { [string compare -nocase $nf2 "Z"] == 0 } {
        set bendingType 2dZ
    } elseif { [string compare -nocase $nf2 "Y"] == 0 } {
        set bendingType 2dY
    } else {
        set bendingType 3d
        set nf2 [expr int($nf2)]
        if { $nf2 <= 0 } {
            error "Error - RectangularRC: the number of fibers (nf2) should be positive"
        }
    }

    if { $fc <= 0.0 } {
        error "Error - RectangularRC: Concrete compressive strength should be input as a posititve value"
    }

    if { $nBarX < 2 || $nBarY < 2 } {
        error "Error - RectangularRC: need at least 2 rebar in each direction"
    }
    
    
    # ########### Define Section by calling itself with secID = noSection ###########
    if { [string compare -nocase $secID "noSection"] != 0 } {
        # Compute GJ
        set Gc  [expr $Ec/(2*(1+0.2))]
        if { $H >= $B } { 
            set ar   [expr $H/$B]
            set beta [expr (1-192.0/(pow($pi,5)*$ar)*(tanh($pi*$ar/2.0)+tanh(3*$pi*$ar/2.0)/243))/3.0]
            set Jc   [expr $beta*$H*pow($B,3)]
        } else {
            set ar   [expr $B/$H]
            set beta [expr (1-192.0/(pow($pi,5)*$ar)*(tanh($pi*$ar/2.0)+tanh(3*$pi*$ar/2.0)/243))/3.0]
            set Jc   [expr $beta*$B*pow($H,3)]
        } 
    
        section Fiber $secID -GJ [expr $Gc*$Jc] {
            eval RectangularRC noSection $startMatID $nf1 $nf2 $units $B $H $fc $Ec $cover $fy $fu $Es $db $Ab $nBarX $nBarY $fyt $dbt $Abt $nLegX $nLegY $s $conc_material $steel_material
        }
        return
    }


    # ########### Compute Confining Pressure ###########
    # Section Geometry
    set Hc      [expr $H - 2*$cover - $dbt]
    set Bc      [expr $B - 2*$cover - $dbt]
    set Ac      [expr $Hc*$Bc]
    
    set zLocBar [expr 0.5*$B - $cover - $dbt - $db/2]
    set yLocBar [expr 0.5*$H - $cover - $dbt - $db/2]
    
    set As      [expr (2*$nBarX + 2*$nBarY - 4)*$Ab]

    # Compute Area of Effectively Confined Conrete Core, Ae
    set wiz     [expr (2*$zLocBar - ($nBarX-1)*$db)/double($nBarX-1)]
    set wiy     [expr (2*$yLocBar - ($nBarY-1)*$db)/double($nBarY-1)]
    set Ae      [expr $Ac - 2*($nBarY-1)*$wiy*$wiy/6.0 - 2*($nBarX-1)*$wiz*$wiz/6.0]
    set sprime  [expr $s-$dbt]
    set Ae      [expr $Ae*(1-$sprime/(2*$Bc))*(1-$sprime/(2*$Hc))]

    # Compute Confining Pressure
    set ke      [expr $Ae/($Ac-$As)]   
    set rhoz    [expr $nLegY*$Abt/($s*$Hc)]
    set rhoy    [expr $nLegX*$Abt/($s*$Bc)]
    set flz     [expr $ke*$rhoz*$fyt]
    set fly     [expr $ke*$rhoy*$fyt]
        
    # Compute Confined Strength
    set xba     [expr ($flz+$fly)/(2.0*$fc)]
    if { $flz >= $fly } {
        set r [expr $fly/$flz] 
    } else {
        set r [expr $flz/$fly]
    }
    set Amm     [expr 6.8886-(0.6069+17.275*$r)*exp(-4.989*$r)]
    set Bmm     [expr 4.5/((5.0/$Amm)*(0.9849-0.6306*exp(-3.8939*$r))-0.1)-5]
    set K       [expr 1+$Amm*$xba*(0.1+0.9/(1+$Bmm*$xba))]
    set fcc     [expr $K*$fc]
    
    # Compute Strain at Peak Streess
    set ec      0.002
    set ecc     [expr $ec*(1+5*($fcc/$fc-1))]
    

    # ########### Set Concrete Materials ###########
    set coverConcID [expr $startMatID]
    set coreConcID  [expr $startMatID+1]
    switch -exact -- $conc_material {
        Concrete04 {
            set ecu 0.05
            uniaxialMaterial Concrete04 $coverConcID -$fc -$ec -$ecu $Ec
            uniaxialMaterial Concrete04 $coreConcID -$fcc -$ecc -$ecu $Ec
        }
        Elastic {
            uniaxialMaterial Elastic $coverConcID $Ec
            # uniaxialMaterial Elastic $coreConcID $Ec
            set coreConcID $coverConcID
        }
        ElasticNoTension {
            uniaxialMaterial ENT $coverConcID $Ec
            set coreConcID $coverConcID
        }
        default {
            error "ERROR: RectangularRC: unknown concrete material type: $conc_material"
        }
    }


    # ########### Define Concrete Fibers: 2d Strong ###########
    if { $bendingType == "2dZ" } {

        # Define cover concrete
        set nfi [expr int(ceil((0.5*$H-0.5*$Hc)*($nf1/$H)))]
        patchRect2d $coverConcID $nfi $B [expr -0.5*$H] [expr -0.5*$Hc]
        set nfi [expr int(ceil(($Hc)*($nf1/$H)))]
        patchRect2d $coverConcID $nfi [expr $B-$Bc] [expr -0.5*$Hc] [expr 0.5*$Hc]
        set nfi [expr int(ceil((0.5*$H-0.5*$Hc)*($nf1/$H)))]
        patchRect2d $coverConcID $nfi $B [expr 0.5*$Hc] [expr 0.5*$H]

        # Define core concrete
        set nfi [expr int(ceil(($Hc)*($nf1/$H)))]
        patchRect2d $coreConcID $nfi $Bc [expr -0.5*$Hc] [expr 0.5*$Hc]

    # ########### Define Concrte Fibers: 2d Weak ###########
    } elseif { $bendingType == "2dY" } {

        # Define cover concrete
        set nfi [expr int(ceil((0.5*$B-0.5*$Bc)*($nf1/$B)))]
        patchRect2d $coverConcID $nfi $H [expr -0.5*$B] [expr -0.5*$Bc]
        set nfi [expr int(ceil(($Bc)*($nf1/$B)))]
        patchRect2d $coverConcID $nfi [expr $H-$Hc] [expr -0.5*$Bc] [expr 0.5*$Bc]
        set nfi [expr int(ceil((0.5*$B-0.5*$Bc)*($nf1/$B)))]
        patchRect2d $coverConcID $nfi $H [expr 0.5*$Bc] [expr 0.5*$B]

        # Define core concrete
        set nfi [expr int(ceil(($Bc)*($nf1/$B)))]
        patchRect2d $coreConcID $nfi $Hc [expr -0.5*$Bc] [expr 0.5*$Bc]

    # ########### Define Concrete Fibers: 3d ###########
    } elseif { $bendingType == "3d" } {

        # Define cover concrete
        set nfij [expr int(ceil((0.5*$H-0.5*$Hc)*($nf2/$H)))]
        set nfjk [expr int(ceil(($B)*($nf1/$B)))]
        patch quad $coverConcID $nfij $nfjk [expr  0.5*$Hc] [expr -0.5*$B] [expr  0.5*$H]  [expr -0.5*$B] [expr  0.5*$H]  [expr 0.5*$B] [expr  0.5*$Hc] [expr 0.5*$B] 
        patch quad $coverConcID $nfij $nfjk [expr -0.5*$H]  [expr -0.5*$B] [expr -0.5*$Hc] [expr -0.5*$B] [expr -0.5*$Hc] [expr 0.5*$B] [expr -0.5*$H]  [expr 0.5*$B] 
        
        set nfij [expr int(ceil(($Hc)*($nf2/$H)))]
        set nfjk [expr int(ceil((0.5*$B-0.5*$Bc)*($nf1/$B)))]
        patch quad $coverConcID $nfij $nfjk [expr -0.5*$Hc] [expr -0.5*$B]  [expr 0.5*$Hc] [expr -0.5*$B]  [expr 0.5*$Hc] [expr -0.5*$Bc] [expr  -0.5*$Hc] [expr -0.5*$Bc] 
        patch quad $coverConcID $nfij $nfjk [expr -0.5*$Hc] [expr  0.5*$Bc] [expr 0.5*$Hc] [expr  0.5*$Bc] [expr 0.5*$Hc] [expr  0.5*$B]  [expr  -0.5*$Hc] [expr  0.5*$B] 
        
        # Define medium confined concrete
        set nfij [expr int(ceil(($Hc)*($nf2/$H)))]
        set nfjk [expr int(ceil(($Bc)*($nf1/$B)))]
        patch quad $coreConcID $nfij $nfjk [expr -0.5*$Hc] [expr -0.5*$Bc] [expr 0.5*$Hc] [expr -0.5*$Bc] [expr 0.5*$Hc] [expr 0.5*$Bc] [expr -0.5*$Hc] [expr 0.5*$Bc] 

    } else {
        error "Error - RectangularRC: unknown bendingAxis"
    }


    # ########### Set Longitudinal Reinforcing Steel Materials ###########
    set reinfSteelID [expr $startMatID+2]
    switch -exact -- $steel_material {
        ElasticPP {
            uniaxialMaterial ElasticPP $reinfSteelID $Es [expr $fy/$Es]
        }
        ElasticSmallStiffness {
            uniaxialMaterial multiSurfaceKinematicHardening $reinfSteelID \
                -Direct $Es 0.0 $fy [expr $Es/1000.0]
        }
        Elastic {
            uniaxialMaterial Elastic $reinfSteelID $Es
        }
        default {
            error "ERROR: RectangularRC: unknown reinforcing steel material type: $steel_material"
        }
    }

    # ########### Define Reinforcing Steel Fibers ###########
    if { $bendingType == "2dZ" } {
    
        # Top Bars
        set yLoc    $yLocBar
        set zLoc    0.0
        set A       [expr $nBarX*$Ab]
        fiber $yLoc $zLoc -$A $coreConcID
        fiber $yLoc $zLoc  $A $reinfSteelID
    
        # Side Bars
        for { set i 1 } { $i <= [expr $nBarY - 2] } { incr i } {
            set yLoc    [expr $yLocBar - $i*(2*$yLocBar)/double($nBarY-1)]
            set zLoc    0
            set A       [expr 2*$Ab]
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID
        }        
        
        # Bottom Bars
        set yLoc    -$yLocBar
        set zLoc    0.0
        set A       [expr $nBarX*$Ab]
        fiber $yLoc $zLoc -$A $coreConcID
        fiber $yLoc $zLoc  $A $reinfSteelID
    
    } elseif { $bendingType == "2dY" } {
    
        # Top Bars
        set yLoc    $zLocBar
        set zLoc    0.0
        set A       [expr $nBarY*$Ab]
        fiber $yLoc $zLoc -$A $coreConcID
        fiber $yLoc $zLoc  $A $reinfSteelID
    
        # Side Bars
        for { set i 1 } { $i <= [expr $nBarX - 2] } { incr i } {
            set yLoc    [expr $zLocBar - $i*(2*$zLocBar)/double($nBarX-1)]
            set zLoc    0.0
            set A       [expr 2*$Ab]    
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID
        }        
        
        # Bottom Bars
        set yLoc    -$zLocBar
        set zLoc    0
        set A       [expr $nBarY*$Ab]
        fiber $yLoc $zLoc -$A $coreConcID
        fiber $yLoc $zLoc  $A $reinfSteelID
    
    } elseif { $bendingType == "3d" } {
    
        # Top and Bottom Bars
        for { set i 1 } { $i <= $nBarX } { incr i } {
            set yLoc    $yLocBar
            set zLoc    [expr -$zLocBar + ($i-1)*(2*$zLocBar)/double($nBarX-1)]
            set A       $Ab
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID
            
            set yLoc    -$yLocBar
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID
        }
    
        # Side Bars
        for { set i 1 } { $i <= [expr $nBarY - 2] } { incr i } {
            set yLoc    [expr $yLocBar - $i*(2*$yLocBar)/double($nBarY-1)]
            set zLoc    -$zLocBar
            set A       $Ab
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID

            set zLoc    $zLocBar
            fiber $yLoc $zLoc -$A $coreConcID
            fiber $yLoc $zLoc  $A $reinfSteelID
        }        

    } else {
        error "Error - RectangularRC: unknown bendingAxis"
    }          
}

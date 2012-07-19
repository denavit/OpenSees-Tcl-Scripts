# Register the package
package provide OpenSeesComposite 0.1

# Create the namespace
namespace eval OpenSeesComposite {
    # Export Material Commands
    namespace export \
        ccftConcreteSakino rcftSteelSakino rcftConcreteSakino \
        hssSteelAbdelRahman \
        shenSteelMaterial changManderConcreteMaterial \
        simplePanelZoneMaterial

    # Export Section Commands
    namespace export \
        ccftSection rcftSection recthssSection wfSection srcSection \
        fourFiberSectionGJ twoFiberSection

    # Export Miscellaneous Commands
    namespace export \
        wShapeLookup eigenRecorder updateRayleighDamping printNodeCoordinates
}
process pmproc {
    container "${params.contPfx}${module.container}:${module.version}"
    
    // Output probability map
    publishDir "${params.pubDir}/${module.name}", mode: 'copy', pattern: '*_Probabilities*.tif'

    // QC
    publishDir "${params.path_qc}/${module.name}", mode: 'copy', pattern: '*Preview*.tif'
    
    // Provenance
    publishDir "${params.path_prov}", mode: 'copy', pattern: '.command.sh',
      saveAs: {fn -> "${task.name}.sh"}
    publishDir "${params.path_prov}", mode: 'copy', pattern: '.command.log',
      saveAs: {fn -> "${task.name}.log"}

    input: tuple val(module), file(model), path(core)

    output:

    tuple val("${module.name}"), path('*_Probabilities*.tif'), emit: pm
    path('*Preview*.tif') optional true
    tuple path('.command.sh'), path('.command.log')

    when:
	params.idxStart <= 4 && params.idxStop >= 4
    
    // We are creating a copy of the model file to deal with some tools locking files
    // Without this copying, the lock prevents parallel execution of multiple processes
    //   if they all use the same model file.
    script:

    // Find module specific parameters and compose a command
    def mparam = params."${module.name}Opts"
    def cmd = "${module.cmd} ${module.input} $core $mparam"
    String m = "${module.name}Model"

    if( params.containsKey(m) ) {
	def mdlcp = "cp-${model.name}"
	"""
        cp $model $mdlcp
        $cmd ${module.model} $mdlcp    
        """
    } else {
	"""
        $cmd
        """
    }
}

workflow probmaps {
    take:
	
    input
    modules

    main:

    // Determine if there are any custom models specified
    modules.map{ it -> String m = "${it.name}Model";
		tuple(it, params.containsKey(m) ?
		      file(params."$m") : 'built-in') }
	.combine(input) |
	pmproc
    
    emit:

    pmproc.out.pm
}

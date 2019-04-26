@Grab('org.codehaus.groovy:groovy-json:2.5.6')

import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import groovy.transform.SourceURI

import static groovy.io.FileType.FILES

Map buildReport(File reportsFolder) {

    def jsonSlurper = new JsonSlurper()

    def rawData = []
    reportsFolder.traverse(type: FILES, nameFilter: ~/.*\.json/) { file ->
        if (file.length() > 0) {
            println "Loading " + file.name
            rawData << jsonSlurper.parseText(file.text)
        } else {
            println "[WARN] Skipping empty file " + file.name
        }
    }

    def authAccess = [] as Set
    def scmAccess = [] as Set

    rawData.forEach { reportEntry ->
        reportEntry.authAccess.each { stat ->
            authAccess << ["server": reportEntry.server, "firstDayOfWeek": stat.firstDayOfWeek, "name": stat.name]
        }
        reportEntry.scmAccess.each { stat ->
            scmAccess << ["server": reportEntry.server, "firstDayOfWeek": stat.firstDayOfWeek, "name": stat.name]
        }
    }

    return [
            "authAccess": authAccess.toSorted(new OrderBy([{ it.firstDayOfWeek }, { it.name }, { it.server.url }])),
            "scmAccess" : scmAccess.toSorted(new OrderBy([{ it.firstDayOfWeek }, { it.name }, { it.server.url }]))]
}

String getRelativePath(File base, File path) {
    return base.toURI().relativize(path.toURI()).getPath();
}

File reportsFolder(File workDir) {
    File reportsFolder = new File(workDir, "/out/reports")
    if (!reportsFolder.exists()) {
        println "[ERROR] The reports folder " + getRelativePath(workDir, reportsFolder) + " doesn't exist."
        System.exit(1)
    }
    if (!reportsFolder.isDirectory()) {
        println "[ERROR] The path " + getRelativePath(workDir, reportsFolder) + " isn't a folder."
        System.exit(1)
    }
    println "Reading individual reports from: " + getRelativePath(workDir, reportsFolder)
    return reportsFolder
}

File reportFile(File workDir) {
    File reportFile = new File(workDir, "/out/aggregated-user-activity.json")
    if (reportFile.exists() && !reportFile.isFile()) {
        println "[ERROR] The path " + getRelativePath(workDir, reportFile) + " isn't a file."
        System.exit(2)
    }
    if (reportFile.exists()) {
        println "[WARN] The report file " + getRelativePath(workDir, reportFile) + " is existing and will be overriden."
    }
    return reportFile
}

// The path of the Groovy script
@SourceURI
URI sourceUri

// The folder where the Groovy script is
File workDir = new File(sourceUri).parentFile

println "Working directory: ${workDir}"

// The report file we generate
File reportFile = reportFile(workDir)

println "Merging user activity reports ..."

reportFile.withWriter { writer ->
    writer.write(JsonOutput.prettyPrint(
            JsonOutput.toJson(
                    buildReport(reportsFolder(workDir))
            )
    ))
}

println "File " + getRelativePath(workDir, reportFile) + " generated"

System.exit(0)

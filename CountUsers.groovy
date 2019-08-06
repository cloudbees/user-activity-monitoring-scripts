@Grab('org.codehaus.groovy:groovy-json:2.5.6')
@Grab('org.codehaus.groovy:groovy-dateutil:2.5.6')
@Grab('info.picocli:picocli:3.9.3')
@Command(
        name = "count-user-activity.sh",
        description = "Count users from /out/aggregated-user-activity.json",
        showDefaultValues = true
)
@picocli.groovy.PicocliScript
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import groovy.transform.Field
import groovy.transform.SourceURI

import java.text.SimpleDateFormat

import static picocli.CommandLine.*

Map buildSummary(File reportFile, Date from) {

    SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd")

    def report = new JsonSlurper().parseText(reportFile.text)

    def authAccess = report.authAccess.findAll { dateFormat.parse(it.firstDayOfMonth).after(from) }
    def authAccessFrom = authAccess*.firstDayOfMonth.min() ?: dateFormat.format(from)
    def authAccessTo = authAccess*.firstDayOfMonth.max() ?: dateFormat.format(new Date())
    def authAccessUsers = authAccess*.name.unique()

    println "${authAccessUsers.size()} user(s) counted as Authenticated from ${authAccessFrom} to ${authAccessTo}"

    def scmAccess = report.scmAccess.findAll { dateFormat.parse(it.firstDayOfMonth).after(from) }
    def scmAccessFrom = scmAccess*.firstDayOfMonth.min() ?: dateFormat.format(from)
    def scmAccessTo = scmAccess*.firstDayOfMonth.max() ?: dateFormat.format(new Date())
    def scmAccessUsers = scmAccess*.name.unique()

    println "${scmAccessUsers.size()} user(s) counted as SCM contributor from ${scmAccessFrom} to ${scmAccessTo}"

    def totalAccessFrom = [authAccessFrom, scmAccessFrom].min() ?: dateFormat.format(from)
    def totalAccessTo = [authAccessTo, scmAccessTo].max() ?: dateFormat.format(new Date())
    def totalUsers = (authAccessUsers + scmAccessUsers).unique()

    println "${totalUsers.size()} user(s) counted as CloudBees Core users from ${totalAccessFrom} to ${totalAccessTo}"

    return [
            "from"     : totalAccessFrom,
            "to"       : totalAccessTo,
            "authUsers": authAccessUsers,
            "scmUsers" : scmAccessUsers]
}

String getRelativePath(File base, File path) {
    return base.toURI().relativize(path.toURI()).getPath();
}

File reportFile(File workDir) {
    File reportFile = new File(workDir, "/out/aggregated-user-activity.json")
    if (reportFile.exists() && !reportFile.isFile()) {
        println "[ERROR] The path " + getRelativePath(workDir, reportFile) + " isn't a file."
        System.exit(1)
    }
    if (!reportFile.exists()) {
        println "[ERROR] The report file " + getRelativePath(workDir, reportFile) + " doesn't exist."
        System.exit(1)
    }
    return reportFile
}

File summaryFile(File workDir) {
    File summaryFile = new File(workDir, "/out/aggregated-user-activity-summary.json")
    if (summaryFile.exists() && !summaryFile.isFile()) {
        println "[ERROR] The path " + getRelativePath(workDir, summaryFile) + " isn't a file."
        System.exit(2)
    }
    if (summaryFile.exists()) {
        println "[WARN] The summary file " + getRelativePath(workDir, summaryFile) + " is existing and will be overriden."
    }
    return summaryFile
}


// The path of the Groovy script
@SourceURI
URI sourceUri

// The folder where the Groovy script is
File workDir = new File(sourceUri).parentFile

println "Working directory: ${workDir}"

// Help CLI option
@Option(names = ["-h", "--help"], usageHelp = true, description = "Show this help message and exit.")
@Field boolean helpRequested

// From CLI option
@Option(names = ["-f", "--from"], description = "Start date to count the number of users. Optional, default is 1 year ago.")
@Field Date from = new Date().minus(365)

// The summary file we generate
File summaryFile = summaryFile(workDir)

println "Counting users ..."

summaryFile.withWriter { writer ->
    writer.write(JsonOutput.prettyPrint(
            JsonOutput.toJson(
                    buildSummary(reportFile(workDir), from)
            )
    ))
}

println "Detailed summary available in: " + getRelativePath(workDir, summaryFile)

System.exit(0)


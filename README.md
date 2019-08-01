# user-activity-monitoring-scripts
Scripts for the User Activity Monitoring plugin

## User guide
Detailed activity reports can be generated across multiple masters using the following scripts:

* [install-user-activity-monitoring-plugin.sh](./install-user-activity-monitoring-plugin.sh)
    * Install the [user-activity-monitoring-plugin](https://go.cloudbees.com/docs/plugins/user-activity-monitoring/) or upgrade it on all the masters. Note that the masters are restarted after the install/upgrade.
    * (!) Script automatically restarts each master after installing/upgrading the user-activity-monitoring-plugin even if the plugin was already at the last version.
* [get-user-activity-monitoring-reports.sh](./get-user-activity-monitoring-reports.sh)
    * gather the list of available masters on this CloudBees Core Operations Center instance
    * generate the reports for each master and put them in JSON files (in `/out/reports`)
* [merge-user-activity-monitoring-reports.sh](./merge-user-activity-monitoring-reports.sh)
    * generates a unique report called `/out/aggregated-user-activity.json`
    * `/out/aggregated-user-activity.json` contains a list of all `authAccess` entries and a list of all `scmAccess` entries
    * The entries contain the `firstDayOfMonth`, the `name` and the `server` entry like:
    ```
    {
        "server": {
            "url": "https://cd.wordsmith.beescloud.com/teams-front-team/",
            "id": "21e47a96ced17c97e72f91cd7f7c6a0f"
        },
        "firstDayOfMonth": "2018-10-01",
        "name": "simon"
    }
    ```
* [count-user-activity.sh](./count-user-activity.sh)
    * displays on the stdout the summary of the users counted from `/out/aggregated-user-activity.json`:
    ```
    1 user(s) counted as Authenticated from 2018-10-01 to 2019-02-01
    3 user(s) counted as SCM contributor from 2018-10-01 to 2018-12-01
    4 user(s) counted as CloudBees Core users from 2018-10-01 to 2019-02-01
    Detailed summary available in: ./aggregated-user-activity-summary.json
    ```
    * Generates a file `/out/aggregated-user-activity-summary.json` with such content:
    ```
    {
       from:"",
       to: "",
       authUsers: ["john", "cyrille" ...],
       scmUsers: ["mike"...],
    }    
    ```

The scripts require a `.env` file, which needs to be co-located with the scripts.
These files needs to have the variables:

* `OPS_CENTER_URL` CloudBees Core Operations Center instance url
* `PLUGIN_CATALOG_REPOSITORY_CREDENTIALS_ID` ID of the credentials to be used to get the plugin from the repository
* `PLUGIN_CATALOG_REPOSITORY_USERNAME` username to connect to the repository
* `PLUGIN_CATALOG_REPOSITORY_PASSWORD` password to connect to the repository

The scripts rely on variables `JENKINS_USER_ID` and `JENKINS_API_TOKEN` being exported. 
If they are not generally available, add them in the `.env` file as well.
Those are used directly by `jenkins-cli.jar` when using a Jenkins instance later than 2.145+ version.

# A wrapper script for Microsoft's diskspd (https://github.com/microsoft/diskspd)
# utility.  Intended to be run on a regular basis (every 15 minutes) from a
# schdueled task.  Only actually runs the diskspd exe a random percentage
# of the time determined by the trigerThresold config value

# Config values
# The path were the diskspd exe lives and the result files end up
$workingPath = "C:\Users\mark.keightley\Desktop\diskbenchmark"
# The path and most importantly the disk the test file goes to
$testPath = "C:\Users\mark.keightley\Desktop\diskbenchmark"
# The threshold for our 'dice roll'. If we roll higher than this
# number we run the benchmark. Aceptable range 1 to 10
$trigerThreshold = 4

function RunBenchmark {
    # Lets get down to business
    Set-Location $workingPath
    
    $runTime = Get-Date
    $month = "{0:D2}" -f $runTime.Month
    $day = "{0:D2}" -f $runTime.Day
    $hour = "{0:D2}" -f $runTime.Hour
    $minute = "{0:D2}" -f $runTime.Minute

    $resultsFile = "$workingPath\results-$($runTime.Year)-$month-$($day)T$hour$minute.txt"
    $dataFile = "$testPath\TestFile.dat"
    $exePath = "$workingPath\diskspd.exe"

    $writePercentage = "-w40", "-w50", "-w0"
    foreach ($wpParam in $writePercentage)
    {
        # These params come from this article
        # http://longwhiteclouds.com/2016/03/14/performance-testing-with-microsoft-diskspd/
        # I don't fully understand the in's and out's of disk performance so these 
        # might be totaly the wrong way to test it
        $params = $wpParam, "-c3G", "-d120", "-r", "-t1", "-o16", "-b64k", "-h", "-Z1G", $dataFile

        & $exePath @params | Out-File -FilePath $resultsFile -Append

        # diskspd seems to leave it's test file behind, that's very untidy of it!
        Remove-Item $dataFile -ErrorAction SilentlyContinue | Out-Null
    }
}

# Start logging stuff if the host supports it
if ($host.Name -eq "ConsoleHost") {
    Clear-Host
    Start-Transcript -Append -Path "$workingPath\transcript.txt"
}

If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

# The timer will run us 96 times in 24 hours, but we only want to run the test about 20% of the time
$diceRoll = Get-Random -Minimum 1 -Maximum 10
if ($diceRoll -gt $trigerThreshold) {
    Write-Host "Rolled a $diceRoll, so it's benchmarking time!"
    RunBenchmark
}
else {
    Write-Host "Rolled a $diceRoll, not running benchmark this time"
}

# Make sure we stop logging otherwise file will be locked next time
if ($host.Name -eq "ConsoleHost") {
    Stop-Transcript
}
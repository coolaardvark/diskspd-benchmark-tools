# Takes the result files from my disk-benchmark script and parses them in
# to a CSV format for easier analysis in a spreadsheet or simlar application

# Config values
# The path holding our result files
$path = 'C:\Users\mark.keightley\Desktop\diskbenchmark-results'
# Full path, including file name, of the output csv file
$outputFile = 'C:\Users\mark.keightley\Desktop\results.csv'

$testTypeRegex = '^\s*performing(.*)$'
$cpuResultRegex = '^CPU\s\|'
$ioResultRegex = '^(\w+)\sIO'

# match a line like this 
# avg.|   3.58%|   1.30%|    2.28%|  96.42%
# we only really want the final percentage
$cpuResultRowRegex = '^avg\.\|(\s+\d{1,2}\.\d{1,2}%\|){3}\s+(\d{1,2}\.\d{1,2}%)$'
# match a line like this
# total:      211001081856 |      3219621 |    1676.87 |   26829.92
# We want all numberic items here
$ioResultRowRegex = '^total:\s+(\d+)\s\|\s+(\d+)\s\|\s+(\d+\.\d{1,2})\s+\|\s+(\d+\.\d{1,2})$'

# Clean up from any previous runs
if ((Test-Path -Path $outputFile) -eq $true) {
    Remove-Item $outputFile -ErrorAction SilentlyContinue | Out-Null
}

Get-ChildItem -Path $path | Where-Object Name -match '.*\.txt' | ForEach-Object {
    $file = $_

    # Status tracking stuff
    $testType = 'none'
    $resultType = 'none'
    $resultSubType = 'none'

    $resultCount = 0

    # date is on the end of the filename and is in the format yyyy-mm-ddThhmm
    $fileName = $file.Name
    $rawDateStr = $fileName.Substring($fileName.IndexOf('-') +1).TrimEnd('.txt')
 
    $dtParts = $rawDateStr.Split('T')
    $dateStr = $dtParts[0] + " " + $dtParts[1].Substring(0,2) + ":" + $dtParts[1].Substring(2,2) + ":00"
    
    # Results variables
    $testTime = $dateStr
    $cpuAvg = 0
    $bytes = 0
    $ios = 0
    $mibsPerSec = 0
    $iosPerSec = 0

    $fileContent = Get-Content $file
    foreach ($line in $fileContent) {
        # We are not yet in a test, so check if this line has a test name in it
        if ($testType -eq 'none') {
            $match = [regex]::Match($line, $testTypeRegex)
            if ($match.Success) {
                $testType = $match.Groups[1]
            }
        }

        # Are we in a test block (no is a purfectly acceptable answer here)
        if ($resultType -eq 'none') {
            $match = [regex]::Match($line, $cpuResultRegex)
            if ($match.Success) {
                $resultType = 'CPU'
            }

            # Okay so it's not a CPU result block, is it an IO one?
            if ($resultType -eq 'none') {
                $match = [regex]::Match($line, $ioResultRegex)
                if ($match.Success) {
                    $resultType = 'IO'
                    $resultSubType = $match.Groups[0].ToString()
                }
            }
        }

        if ($resultType -eq 'CPU') {
            # We are inside some test results so see if this line contains
            # the result table

            $match = [regex]::Match($line, $cpuResultRowRegex)
            if ($match.Success) {
                $cpuAvg = $match.Groups[2].ToString()

                # Only 1 row of CPU results so reset that flag now
                $resultType = 'none'
                $resultCount++
            }
        }
            
        if ($resultType -eq 'IO') {
            $match = [regex]::Match($line, $ioResultRegex)
            if ($match.Success) {
                $resultSubType = $match.Groups[1].ToString()
            }

            $match = [regex]::Match($line, $ioResultRowRegex)
            if ($match.Success) {
                $bytes = $match.Groups[1]
                $ios = $match.Groups[2]
                $mibsPerSec = $match.Groups[3]
                $iosPerSec = $match.Groups[4]

                $Output = New-Object -TypeName PSObject -Property @{
                    TestTime = $testTime
                    TestType = $testType
                    ResultType = "$resultType $resultSubType"
                    CPUAgv = $cpuAvg
                    TotalBytes = $bytes
                    TotalIOs = $ios
                    MiBperSec = $mibsPerSec
                    IOPs = $iosPerSec
                } | Select-Object TestTime, TestType, ResultType, CPUAgv, TotalBytes, TotalIOs, MiBperSec, IOPs
        
                $Output | Export-CSV $outputFile -Append

                $resultCount++
            }           
        }

        # Once we have 4 result lines, that's it for this test so reset everything 
        if ($resultCount -eq 4) {
            $testType = 'none'
            $resultType = 'none'
            $resultSubType = 'none'

            $cpuAvg = 0
            $bytes = 0
            $ios = 0
            $mibsPerSec = 0
            $iosPerSec = 0

            $resultCount = 0
        }
    }
}
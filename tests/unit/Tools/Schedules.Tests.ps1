$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeSchedule' {
    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Get-PodeSchedule -Name $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { Get-PodeSchedule -Name ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid values supplied' {
        It 'Returns null as the schedule does not exist' {
            $PodeSession = @{ 'Schedules' = @{}; }
            Get-PodeSchedule -Name 'test' | Should Be $null
        }

        It 'Returns schedule for name' {
            $PodeSession = @{ 'Schedules' = @{ 'test' = @{ 'Name' = 'test'; }; }; }
            $result = (Get-PodeSchedule -Name 'test')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Name | Should Be 'test'
        }
    }
}

Describe 'Schedule' {
    Mock 'ConvertFrom-CronExpression' { @{} }

    Context 'Invalid parameters supplied' {
        It 'Throw null name parameter error' {
            { Schedule -Name $null -Cron '@hourly' -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty name parameter error' {
            { Schedule -Name ([string]::Empty) -Cron '@hourly' -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw null cron parameter error' {
            { Schedule -Name 'test' -Cron $null -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty cron parameter error' {
            { Schedule -Name 'test' -Cron ([string]::Empty) -ScriptBlock {} } | Should Throw 'The argument is null or empty'
        }

        It 'Throw null scriptblock parameter error' {
            { Schedule -Name 'test' -Cron '@hourly' -ScriptBlock $null } | Should Throw 'The argument is null'
        }
    }

    Context 'Valid schedule parameters' {
        It 'Throws error because schedule already exists' {
            $PodeSession = @{ 'Schedules' = @{ 'test' = $null }; }
            { Schedule -Name 'test' -Cron '@hourly' -ScriptBlock {} } | Should Throw 'already exists'
        }

        It 'Throws error because end time in the past' {
            $PodeSession = @{ 'Schedules' = @{}; }
            $end = ([DateTime]::Now.AddHours(-1))
            { Schedule -Name 'test' -Cron '@hourly' -ScriptBlock {} -EndTime $end } | Should Throw 'endtime in the future'
        }

        It 'Throws error because start time is after end time' {
            $PodeSession = @{ 'Schedules' = @{}; }
            $start = ([DateTime]::Now.AddHours(3))
            $end = ([DateTime]::Now.AddHours(1))
            { Schedule -Name 'test' -Cron '@hourly' -ScriptBlock {} -StartTime $start -EndTime $end } | Should Throw 'starttime after the endtime'
        }

        It 'Adds new schedule to session' {
            $PodeSession = @{ 'Schedules' = @{}; }
            $start = ([DateTime]::Now.AddHours(3))
            $end = ([DateTime]::Now.AddHours(5))

            Schedule -Name 'test' -Cron '@hourly' -ScriptBlock { Write-Host 'hello' } -StartTime $start -EndTime $end

            $schedule = $PodeSession.Schedules['test']
            $schedule | Should Not Be $null
            $schedule.Name | Should Be 'test'
            $schedule.StartTime | Should Be $start
            $schedule.EndTime | Should Be $end
            $schedule.Script | Should Not Be $null
            $schedule.Script.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}
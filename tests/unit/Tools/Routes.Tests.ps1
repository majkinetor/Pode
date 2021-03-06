$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeSession = @{ 'Server' = $null; }

Describe 'Get-PodeRoute' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Get-PodeRoute -HttpMethod 'MOO' -Route '/' } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throw null route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid method and route' {
        It 'Return null as method does not exist' {
            $PodeSession.Server = @{ 'Routes' = @{}; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @{ 'Logic'= { Write-Host 'Test' }; }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and middleware for method and exact route' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @{ 'Logic'= { Write-Host 'Test' }; 'Middleware' = { Write-Host 'Middle' }; }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Middleware.ToString() | Should Be ({ Write-Host 'Middle' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route under star' {
            $PodeSession.Server = @{ 'Routes' = @{ '*' = @{ '/' = @{ 'Logic'= { Write-Host 'Test' }; }; }; }; }
            $result = (Get-PodeRoute -HttpMethod * -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[\w-_]+?)' = @{ 'Logic'= { Write-Host 'Test' }; }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/123')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()

            $result.Parameters | Should BeOfType System.Collections.Hashtable
            $result.Parameters['userId'] | Should Be '123'
        }
    }
}

Describe 'Route' {
    Context 'Invalid parameters supplied' {
        It 'Throws invalid method error for no method' {
            { Route -HttpMethod 'MOO' -Route '/' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throws null route parameter error' {
            { Route -HttpMethod GET -Route $null -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throws empty route parameter error' {
            { Route -HttpMethod GET -Route ([string]::Empty) -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throws null logic and middleware error' {
            { Route -HttpMethod GET -Route '/' -Middleware $null -ScriptBlock $null } | Should Throw 'no logic defined'
        }
    }

    Context 'Valid route parameters' {
        It 'Throws error because only querystring has been given' {
            { Route -HttpMethod GET -Route "?k=v" -ScriptBlock {} } | Should Throw "No route supplied"
        }

        It 'Throws error because route already exists' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = $null; }; }; }
            { Route -HttpMethod GET -Route '/' -ScriptBlock {} } | Should Throw 'already defined'
        }

        It 'Adds route with simple url' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users') | Should Be $true
            $route['/users'] | Should Not Be $null
            $route['/users'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users'].Middleware | Should Be $null
        }

        It 'Adds route with middleware supplied and no logic' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -Middleware { Write-Host 'middle' } -ScriptBlock $null

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Not Be $null

            $route.Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
            $route.Middleware | Should Be $null
        }

        It 'Adds route with middleware and logic supplied' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -Middleware { Write-Host 'middle' } -ScriptBlock { Write-Host 'logic' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Not Be $null

            $route.Logic.ToString() | Should Be ({ Write-Host 'logic' }).ToString()

            $route.Middleware.Length | Should Be 1
            $route.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
        }

        It 'Throws error for route with array of middleware and no logic supplied' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }

            { Route -HttpMethod GET -Route '/users' -Middleware @(
                { Write-Host 'middle1' },
                { Write-Host 'middle2' }
             ) -ScriptBlock $null } | Should Throw 'no logic defined'

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Be $null
        }

        It 'Adds route with array of middleware and logic supplied' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -Middleware @(
                { Write-Host 'middle1' },
                { Write-Host 'middle2' }
             ) -ScriptBlock { Write-Host 'logic' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Not Be $null

            $route.Logic.ToString() | Should Be ({ Write-Host 'logic' }).ToString()
            $route.Middleware.Length | Should Be 2
            $route.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $route.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds route with simple url and querystring' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users?k=v' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users') | Should Be $true
            $route['/users'] | Should Not Be $null
            $route['/users'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users'].Middleware | Should Be $null
        }

        It 'Adds route with url parameters' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
        }

        It 'Adds route with url parameters and querystring' {
            $PodeSession.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId?k=v' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
        }
    }
}
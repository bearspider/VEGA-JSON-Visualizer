Param($filename)

function flatten
{
    Param($jsonobject,$parent,[ref]$jsonarray,[ref]$currentid)

    foreach($jsonproperty in ($jsonobject.psobject.properties))
    {
        $currentid.value += 1
        $output = @{"name"=$jsonproperty.Name;"parent"=$parent;"id"=$currentid.value}
        $jsonarray.value += $output
        if((($jsonproperty.Value).gettype()).name -eq "PSCustomObject")
        {
            flatten -jsonobject $jsonproperty.Value -parent $currentid.value -jsonarray $jsonarray -currentid $currentid          
        }
        else
        {
            $currentid.value += 1
            if(($jsonproperty.value).gettype().name -eq "String")
            {
                $value = [string]($jsonproperty.value).replace("`n",", ").replace("`r",", ").replace("\","/")
            }
            else
            {
                $value = $jsonproperty.value
            }
            $output = @{"name"=$($Value);"parent"=($currentid.value - 1);"id"=$currentid.value}
            $jsonarray.value += $output
        }
    }
}

$filecontent = Get-Content $filename
$fromjson = ($filecontent | ConvertFrom-Json)
$filesplit = $filename.split("\")
$exportname = ($filesplit[($filesplit.count - 1)]).split(".")[0]

$rootnode = @{"name"=$exportname;"id"=1}
$json = @()
$json += $rootnode
$current = 1
flatten -jsonobject $fromjson -parent 1 -jsonarray ([ref]$json) -currentid ([ref]$current)
$signals = @(@{"name"="labels";"value"="true";"bind"=@{"input"="checkbox"}},
            @{"name"="layout";"value"="tidy";"bind"=@{"input"="radio";"options"=@("tidy","cluster")}},
            @{"name"="links";"value"="diagonal";"bind"=@{"input"="select";"options"=@("line","curve","diagonal","orthogonal")}}
            )
$data = @(@{"name"="esdata";"values"=$json},
@{"name"="tree";"source"="esdata";"transform"=@(@{"type"="stratify";"key"="id";"parentKey"="parent"};@{"type"="tree";"method"=@{"signal"="layout"};"size"=@(@{"signal"="height"},@{"signal"="width - 100"});"as"=@("y","x","depth","children")})},
@{"name"="links";"source"="tree";"transform"=@(@{"type"="treelinks";"key"="id"},@{"type"="linkpath";"orient"="horizontal";"shape"=@{"signal"="links"}})}
)
$scales = @(@{"name"="color";"type"="sequential";"range"=@{"scheme"="magma"};"domain"=@{"data"="tree";"field"="depth"};"zero"="true"})
$vegamarks = @(@{"type"="path";"from"=@{"data"="links"};"encode"=@{"update"=@{"path"=@{"field"="path"};"stroke"=@{"value"="#ccc"}}}},
@{"type"="symbol";"from"=@{"data"="tree"};"encode"=@{"enter"=@{"size"=@{"value"=100};"stroke"=@{"value"="#fff"}};"update"=@{"x"=@{"field"="x"};"y"=@{"field"="y"};"fill"=@{"scale"="color";"field"="depth"}}}},
@{"type"="text";"from"=@{"data"="tree"};"encode"=@{"enter"=@{"text"=@{"field"="name"};"fontSize"=@{"value"=9};"baseline"=@{"value"="middle"}};"update"=@{"x"=@{"field"="x"};"y"=@{"field"="y"};"dx"=@{"signal"="datum.children ? -7 : 7"};"align"=@{"signal"="datum.children ? 'right' : 'left'"};"opacity"=@{"signal"="labels ? 1 : 0"}}}}
)
$vega = @{'$schema'="https://vega.github.io/schema/vega/v3.0.json";"width"=600;"height"=1600;"padding"=5;"autosize"="pad";"signals"=$signals;"data"=$data;"scales"=$scales;"marks"=$vegamarks}

$vegajson = ConvertTo-Json -InputObject $vega -Depth 20 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) }
[IO.File]::WriteAllLines("c:\storage\$($exportname)-visual.json",$vegajson)
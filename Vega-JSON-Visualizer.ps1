<#
.DESCRIPTION
  This Powershell will create a VEGA TREE visualization .JSON file, which you can render in your preferred VEGA method.
      - filename is the file location of the .json file
      (ex. C:\storage\myfile.json)

.PARAMETER filename
   Mandatory with no default.
   location of .json file to visualize
   
.NOTES
      
#>
Param($filename)

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER jsonobject
Parameter description

.PARAMETER parent
Parameter description

.PARAMETER jsonarray
Parameter description

.PARAMETER currentid
Parameter description

.EXAMPLE
An example

.NOTES
General notes
    Flatten takes a json file and then creates a hash which separates out the data in parent/child format.
    Input:
        [String]$JSONOBJECT - the information we read in from the file converted FROM JSON
        [INT]$PARENT - The ID of the parent for the object
        [REF]$JSONARRAY - Array by Reference which contains the HASHES of each "object" which is a string, child, parent
        [REF]$CURRENTID - This is an INT variable by reference which is continually passed so that we do no duplicate IDs
    
    Output: NONE
        All data is written to the passed in Array by reference.
#>
function flatten
{
    Param($jsonobject,$parent,[ref]$jsonarray,[ref]$currentid)

    <#Loop through each "property", Increment the ID so each property has a unique identifer.  Create the HASH for that "node", write it to the array.
        If the property is a custom object, that means there are more children, recursively call the function until we end up with only a child node.
        If the property is the child node, create the hash and write it to the array.
    #>
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

#Read in the entire JSON file
$filecontent = Get-Content $filename
#Convert the information FROM JSON
$fromjson = ($filecontent | ConvertFrom-Json)

#Grab the entire filename, split it out, so we only grab the filename and not the path information.
$filesplit = $filename.split("\")
$exportname = ($filesplit[($filesplit.count - 1)]).split(".")[0]

#Create a "ROOT" node HASH which is essentially the filename.  This will have no PARENT
$rootnode = @{"name"=$exportname;"id"=1}

#Create our empty array which will contain the HASHES of our data
$json = @()
#Add the root node
$json += $rootnode
#Create the "Counter" for our IDs
$current = 1

#Call the Flatten function to create the array of HASHES
flatten -jsonobject $fromjson -parent 1 -jsonarray ([ref]$json) -currentid ([ref]$current)

#Create the Signals section for VEGA
$signals = @(@{"name"="labels";"value"="true";"bind"=@{"input"="checkbox"}},
            @{"name"="layout";"value"="tidy";"bind"=@{"input"="radio";"options"=@("tidy","cluster")}},
            @{"name"="links";"value"="diagonal";"bind"=@{"input"="select";"options"=@("line","curve","diagonal","orthogonal")}}
            )

#Create the Data section for VEGA
$data = @(@{"name"="esdata";"values"=$json},
@{"name"="tree";"source"="esdata";"transform"=@(@{"type"="stratify";"key"="id";"parentKey"="parent"};@{"type"="tree";"method"=@{"signal"="layout"};"size"=@(@{"signal"="height"},@{"signal"="width - 100"});"as"=@("y","x","depth","children")})},
@{"name"="links";"source"="tree";"transform"=@(@{"type"="treelinks";"key"="id"},@{"type"="linkpath";"orient"="horizontal";"shape"=@{"signal"="links"}})}
)

#Create the Scales section for VEGA
$scales = @(@{"name"="color";"type"="sequential";"range"=@{"scheme"="magma"};"domain"=@{"data"="tree";"field"="depth"};"zero"="true"})

#Create the Marks secction for VEGA
$vegamarks = @(@{"type"="path";"from"=@{"data"="links"};"encode"=@{"update"=@{"path"=@{"field"="path"};"stroke"=@{"value"="#ccc"}}}},
@{"type"="symbol";"from"=@{"data"="tree"};"encode"=@{"enter"=@{"size"=@{"value"=100};"stroke"=@{"value"="#fff"}};"update"=@{"x"=@{"field"="x"};"y"=@{"field"="y"};"fill"=@{"scale"="color";"field"="depth"}}}},
@{"type"="text";"from"=@{"data"="tree"};"encode"=@{"enter"=@{"text"=@{"field"="name"};"fontSize"=@{"value"=9};"baseline"=@{"value"="middle"}};"update"=@{"x"=@{"field"="x"};"y"=@{"field"="y"};"dx"=@{"signal"="datum.children ? -7 : 7"};"align"=@{"signal"="datum.children ? 'right' : 'left'"};"opacity"=@{"signal"="labels ? 1 : 0"}}}}
)

#Piece together the Entire VEGA JSON
$vega = @{'$schema'="https://vega.github.io/schema/vega/v3.0.json";"width"=600;"height"=1600;"padding"=5;"autosize"="pad";"signals"=$signals;"data"=$data;"scales"=$scales;"marks"=$vegamarks}

#Convert the VEGA information to JSON
$vegajson = ConvertTo-Json -InputObject $vega -Depth 20 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) }

#Write the JSON to file
[IO.File]::WriteAllLines("c:\storage\$($exportname)-visual.json",$vegajson)
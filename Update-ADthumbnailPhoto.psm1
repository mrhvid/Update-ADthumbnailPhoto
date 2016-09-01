function Update-ADthumbnailPhoto
{
<#
.Synopsis
   Update user photo in AD (Outlook and Lync)
.DESCRIPTION
   Requires a .jpg
   Less than 10 KB and 96x96 is recommended thumbnail size. See: http://blogs.technet.com/b/exchange/archive/2010/03/10/3409495.aspx
.NOTES
   Created by Jonas Sommer - 2014
.EXAMPLE
   Update-DSSadUserPhoto josoni \\Fileserver\Data\MedarbejderPhoto\cap\AD\Backup\josoni96x96.jpg
.EXAMPLE
   This WILL fail!

   Update-DSSadUserPhoto josoni .\josoni.jpg

   This WILL fail! This is a known bug. 

.EXAMPLE

Resize images to max 96x96 pixels
ls -File | Set-ImageSize -Destination C:\temp\pics\96\ -WidthPx 96 -HeightPx 96

#>
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [String]$UserName = $env:USERNAME,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({ (Test-Path $_) -and (($_ -like "*.jpg") -or ($_ -like "*.jpeg"))  #Test that path ends with .jpg or .jpeg (quick n dirty) 
                        })] 
        [String]$Path,

        [Switch]$UseRSAT = $false,

        [Switch]$Ignore96pxCheck = $false
    )

    Begin
    {
    }
    Process
    {
 
      # Check size of image (96x96 pixels is preferred)
      Add-Type -AssemblyName System.Drawing

      try
      {
        $img = [System.Drawing.Image]::FromFile($Path)
        $Size = $img.Clone() | Select-Object Width, Height
        $img.Dispose()  
      }
      catch
      {
          Write-Error -Message "Error opening image file. ($Path)"
          return
      }

      Write-Verbose -Message "Image Height: $($Size.Height)px Width: $($Size.Width)px"
      If (! $Ignore96pxCheck) {
        If (!($Size.Height -le 96 -and $Size.Width -le 96)) {
        
          Write-Error -Message "Image Height: $($Size.Height)px Width: $($Size.Width)px (Resize to 96x96 px)"
          return
        
        }    
      }
        
        if ($UseRSAT) { 
          # Using RSAT Set-ADUser to update photo

          $User = Get-ADUser -Identity $UserName

          if($User) {
            Write-Verbose -Message "$UserName found in AD: $($User.UserPrincipalName)"

            $Picture=[System.IO.File]::ReadAllBytes($Path)
            # [byte[]]$Picture = Get-Content $Path -Encoding byte    # Propperly works fine, haven't tested. 

            $User | Set-ADUser -Replace @{thumbnailphoto=$Picture}

            Write-Verbose -Message "$Path saved to $User"

          } else {
            Write-Error -Message "$UserName not found in AD"
          }

        } else {
            # Using adsi LDAP 
            # Using examples from https://social.technet.microsoft.com/Forums/scriptcenter/en-US/403cda19-7a63-4d95-a273-8f7885e836cd/how-i-can-update-thumbnailphoto-ad-attribute-with-powershell?forum=ITCG
            
            $dom = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $root = $dom.GetDirectoryEntry()
            $search = [System.DirectoryServices.DirectorySearcher]$root
            $search.Filter = "(&(objectclass=user)(objectcategory=person)(samAccountName=$UserName))"
            $result = $search.FindOne()

            if ($result -ne $null)
            {

              $user = $result.GetDirectoryEntry()
              [byte[]]$Picture = Get-Content $Path -encoding byte
              $user.put("thumbnailPhoto",  $Picture )
              $user.setinfo()
              Write-Verbose -message "$($user.displayname) updated"

            } else {
            
              Write-Error -Message "$struser Does not exist"

            }

        }

    }
    End
    {
    }
}
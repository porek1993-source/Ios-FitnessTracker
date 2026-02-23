# TestGemini.ps1
# Script to verify Gemini 2.5-flash-lite API connectivity

$ApiKey = Read-Host "Enter your Gemini API Key"
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "API Key is required." -ForegroundColor Red
    exit
}

$Model = "gemini-2.5-flash-lite"
$Url = "https://generativelanguage.googleapis.com/v1beta/models/$($Model):generateContent?key=$ApiKey"

$Body = @{
    system_instruction = @{
        parts = @(@{ text = "Jsi fitness trenér Jakub. Odpovídej vždy krátce a v češtině." })
    }
    contents = @(
        @{
            role = "user"
            parts = @(@{ text = "Ahoj, jsi připraven mi pomoct s tréninkem?" })
        }
    )
    generationConfig = @{
        temperature = 0.4
        maxOutputTokens = 100
    }
} | ConvertTo-Json -Depth 10

Write-Host "Connecting to Gemini ($Model)..." -ForegroundColor Cyan

try {
    $Response = Invoke-RestMethod -Uri $Url -Method Post -Body $Body -ContentType "application/json"
    $Text = $Response.candidates[0].content.parts[0].text
    Write-Host "`nGemini Response:" -ForegroundColor Green
    Write-Host "----------------"
    Write-Host $Text
    Write-Host "----------------"
    Write-Host "`nVerification SUCCESSFUL! The model $Model is active and responding." -ForegroundColor Green
} catch {
    Write-Host "`nVerification FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $ErrorBody = $Reader.ReadToEnd()
        Write-Host "Server Response: $ErrorBody" -ForegroundColor Yellow
    }
}

Read-Host "`nPress Enter to exit"

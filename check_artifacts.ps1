$response = Invoke-RestMethod -Uri "https://api.github.com/repos/200012Yoel/SarahAI/actions/runs/32506576102/artifacts" -Headers @{ "User-Agent" = "Downloader" }
$response.artifacts | ForEach-Object {
    Write-Host "Artifact: $($_.name) - ID: $($_.id) - Size: $($_.size_in_bytes)"
}

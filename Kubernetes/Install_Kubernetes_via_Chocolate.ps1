
If ( (Get-ExecutionPolicy) -ne "RemoteSigned")
{
set-ExecutionPolicy RemoteSigned -Scope Process -Force
}

# Install Chocolate on PowerShell
iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

#Close PowerShell

# Access Chocolate
choco

# Automatically install
choco feature enable -n allowGlobalConfirmation

# Install Kubernetes on Chocolate
choco install kubernetes-cli -y --force

# Check to see the install worked
kubectl version

# Setup Secure Config File
cd $Home #Home Directory
mkdir .kube
cd .kube
New-Item -Name config
####
# Configure AD Domain Services - Post Deployment
# Requires Wrapper Library (cookbook.windows_ad): https://github.com/TAMUArch/cookbook.windows_ad.git
####

# Domain Name
domain = 'addstst.com'

# Local management tool setup
if Chef::Version.new(node['os_version']) >= Chef::Version.new('6.2')
  %w(
    Microsoft-Windows-GroupPolicy-ServerAdminTools-Update
    ServerManager-Core-RSAT
    ServerManager-Core-RSAT-Role-Tools
    RSAT-AD-Tools-Feature
    RSAT-ADDS-Tools-Feature
    ActiveDirectory-Powershell
    DirectoryServices-DomainController-Tools
    DirectoryServices-AdministrativeCenter
    DirectoryServices-DomainController
  ).each do |feature|
    windows_feature feature do
      action :install
      all true
    end
  end
else
  %w(
    NetFx3
    Microsoft-Windows-GroupPolicy-ServerAdminTools-Update
    DirectoryServices-DomainController
  ).each do |feature|
    windows_feature feature do
      action :install
    end
  end
  Chef::Log.warn('This version of Windows Server may be missing some resouce support. Help us out by submitting a pull request.')
end


# Create OU Structure
windows_ad_ou 'UKSouth' do
  action :create
  domain_name domain
end

# Create AD Groups
windows_ad_group 'Group1' do
  action :create
  ou 'UKSouth'
  domain_name domain
  options ({ "desc" => "Security Group1"
          })
end

windows_ad_group 'Group2' do
  action :create
  ou 'UKSouth'
  domain_name domain
  options ({ "desc" => "Security Group2"
          })
end

# Create Users
# Create user "Joe Smith" in the Users OU
windows_ad_user "Joe Smith" do
  action :create
  domain_name domain
  ou "UKSouth"
  options ({ "samid" => "JSmith",
          "upn" => "JSmith@" + domain,
          "fn" => "Joe",
          "ln" => "Smith",
          "display" => "Smith, Joe",
          "disabled" => "no",
          "pwd" => "Passw0rd"
        })
end

windows_ad_user "Jane Doe" do
  action :create
  domain_name domain
  ou "UKSouth"
  options ({ "samid" => "JDoe",
          "upn" => "JDoe@" + domain,
          "fn" => "Jane",
          "ln" => "Doe",
          "display" => "Doe, Jane",
          "disabled" => "no",
          "pwd" => "Passw0rd"
        })
end


# Add user "Joe Smith" in the Users OU to group "Admins" in OU "AD/Groups"
windows_ad_group_member 'Joe Smith' do
  action :add
  group_name  'Group1'
  domain_name domain
  user_ou 'UKSouth'
  group_ou 'UKSouth'
end

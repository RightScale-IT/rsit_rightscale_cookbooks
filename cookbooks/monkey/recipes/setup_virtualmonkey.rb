#
# Cookbook Name:: monkey
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

packages = value_for_platform(
  "centos" => {
    "default" => ["libxml2-devel", "libxslt-devel", "file"]
  },
  "ubuntu" => {
    "default" => ["libxml2-dev", "libxml-ruby", "libxslt1-dev", "libmagic-dev"]
  }
)

# Installing packages required by VirtualMonkey
log "  Installing packages required by VirtualMonkey"
packages.each do |pkg|
  package pkg
end

# Checking out VirtualMonkey repository
log "  Checking out VirtualMonkey repository from:" +
  " #{node[:monkey][:virtualmonkey][:monkey_repo_url]}"
git node[:monkey][:virtualmonkey_path] do
  repository node[:monkey][:virtualmonkey][:monkey_repo_url]
  reference node[:monkey][:virtualmonkey][:monkey_repo_branch]
  action :sync
end

# By default chef changes the checked out branch to a branch named 'deploy'
# locally. To make sure we can pull/push changes, let's checkout the correct
# branch again!
#
execute "git checkout" do
  cwd node[:monkey][:virtualmonkey_path]
  command "git checkout #{node[:monkey][:virtualmonkey][:monkey_repo_branch]}"
end

# Check out right_api_object project from the Github repository
log "  Checking out right_api_objects project from:" +
  " #{node[:monkey][:virtualmonkey][:right_api_objects_repo_url]}"
git "#{node[:monkey][:user_home]}/right_api_objects" do
  repository node[:monkey][:virtualmonkey][:right_api_objects_repo_url]
  reference node[:monkey][:virtualmonkey][:right_api_objects_repo_branch]
  action :sync
end

# Check out the correct branch for right_api_objects
execute "git checkout" do
  cwd "#{node[:monkey][:user_home]}/right_api_objects"
  command "git checkout" +
    " #{node[:monkey][:virtualmonkey][:right_api_objects_repo_branch]}"
end

# Install the dependencies of right_api_objects
execute "bundle install" do
  cwd "#{node[:monkey][:user_home]}/right_api_objects"
  command "bundle install"
end

# Install the right_api_objects gem
execute "rake install" do
  cwd "#{node[:monkey][:user_home]}/right_api_objects"
  command "rake install"
end

# Install Virtualmonkey dependencies
log "  Installing Virtualmonkey dependencies"
execute "bundle install" do
  cwd node[:monkey][:virtualmonkey_path]
  command "bundle install --no-color --system"
end

# Create the VirtualMonkey configuration file from template. Currently, this
# configuration file is not managed by Chef.
log "  Creating VirtualMonkey configuration file from template"
execute "copy virtualmonkey configuration file" do
  cwd node[:monkey][:virtualmonkey_path]
  command "cp config.yaml .config.yaml"
  not_if do
    ::File.exists?("#{node[:monkey][:virtualmonkey_path]}/.config.yaml")
  end
end

# Populate all virtualmonkey cloud variables
log "  Populating virtualmonkey cloud variables"
execute "populate cloud variables" do
  command "#{node[:monkey][:virtualmonkey_path]}/bin/monkey" +
    " populate_all_cloud_vars" +
    " --force" +
    " --overwrite" +
    " --yes"
end

###############################################################################
# The following code checks out the virtualmonkey nextgen code and sets it up
# so we don't have to launch different monkeys for testing the nextgen
# collateral. This code should be removed from the template when the TOS
# collateral is abondoned.
#
# Checking out VirtualMonkey repository
log "  Checking out VirtualMonkey repository from:" +
  " #{node[:monkey][:virtualmonkey][:monkey_repo_url]}"
git "#{node[:monkey][:virtualmonkey_path]}-ng" do
  repository node[:monkey][:virtualmonkey][:monkey_repo_url]
  reference "colrefactor"
  action :sync
end

# By default chef changes the checked out branch to a branch named 'deploy'
# locally. To make sure we can pull/push changes, let's checkout the correct
# branch again!
#
execute "git checkout" do
  cwd "#{node[:monkey][:virtualmonkey_path]}-ng"
  command "git checkout colrefactor"
end

# Install Virtualmonkey dependencies
log "  Installing Virtualmonkey dependencies"
execute "bundle install" do
  cwd "#{node[:monkey][:virtualmonkey_path]}-ng"
  command "bundle install --no-color --system"
end

# Create the VirtualMonkey configuration file from template. Currently, this
# configuration file is not managed by Chef.
log "  Creating VirtualMonkey configuration file from template"
execute "copy virtualmonkey configuration file" do
  cwd "#{node[:monkey][:virtualmonkey_path]}-ng"
  command "cp config.yaml .config.yaml"
  not_if do
    ::File.exists?("#{node[:monkey][:virtualmonkey_path]}-ng/.config.yaml")
  end
end

# Populate all virtualmonkey cloud variables
log "  Populating virtualmonkey cloud variables"
execute "populate cloud variables" do
  command "#{node[:monkey][:virtualmonkey_path]}-ng/bin/monkey" +
    " populate_all_cloud_vars" +
    " --force" +
    " --overwrite" +
    " --yes"
end

# Add virtualmonkey-ng to PATH
file "/etc/profile.d/virtualmonkey-ng.sh" do
  owner "root"
  group "root"
  mode 0755
  content "export PATH=#{node[:monkey][:virtualmonkey_path]}-ng/bin:$PATH"
  action :create
end

# Checkout the nextgen collateral project and configure it
nextgen_collateral_name = "rightscale_cookbooks_private"
nextgen_collateral_repo_url =
  "git@github.com:rightscale/rightscale_cookbooks_private.git"

log "  Checking out nextgen collateral repo to" +
  " #{nextgen_collateral_name}"
git "/root/#{nextgen_collateral_name}" do
  repository nextgen_collateral_repo_url
  reference node[:monkey][:virtualmonkey][:collateral_repo_branch]
  action :sync
end

execute "git checkout" do
  cwd "/root/#{nextgen_collateral_name}"
  command "git checkout" +
    " #{node[:monkey][:virtualmonkey][:collateral_repo_branch]}"
end

log "  Installing gems required for the nextgen collateral project"
execute "bundle install on collateral" do
  cwd "/root/#{nextgen_collateral_name}"
  command "bundle install --no-color --system"
end

###############################################################################

# Add virtualmonkey to PATH
file "/etc/profile.d/virtualmonkey.sh" do
  owner "root"
  group "root"
  mode 0755
  content "export PATH=#{node[:monkey][:virtualmonkey_path]}/bin:$PATH"
  action :create
end

# Installing right_cloud_api gem from the template file found in rightscale
# cookbook. The rightscale::install_tools installs this gem in sandbox ruby
# and we want it in system ruby
#
log "  Installing the right_cloud_api gem"
gem_package "right_cloud_api" do
  gem_binary "/usr/bin/gem"
  source ::File.join(
    ::File.dirname(__FILE__),
    "..",
    "..",
    "rightscale",
    "files",
    "default",
    "right_cloud_api-#{node[:monkey][:right_cloud_api_version]}.gem"
  )
  action :install
end

log "  Obtaining collateral project name from repo URL"
basename_cmd = Mixlib::ShellOut.new("basename" +
  " #{node[:monkey][:virtualmonkey][:collateral_repo_url]} .git"
)
basename_cmd.run_command
basename_cmd.error!

node[:monkey][:virtualmonkey][:collateral_name] = basename_cmd.stdout.chomp

log "  Checking out collateral repo to" +
  " #{node[:monkey][:virtualmonkey][:collateral_name]}"
git "/root/#{node[:monkey][:virtualmonkey][:collateral_name]}" do
  repository node[:monkey][:virtualmonkey][:collateral_repo_url]
  reference node[:monkey][:virtualmonkey][:collateral_repo_branch]
  action :sync
end

execute "git checkout" do
  cwd "/root/#{node[:monkey][:virtualmonkey][:collateral_name]}"
  command "git checkout" +
    " #{node[:monkey][:virtualmonkey][:collateral_repo_branch]}"
end

log "  Installing gems required for the collateral project"
execute "bundle install on collateral" do
  cwd "/root/#{node[:monkey][:virtualmonkey][:collateral_name]}"
  command "bundle install --no-color --system"
end

# Copyright (c) 2017 Suse Linux
# Licensed under the terms of the MIT license.

require "xmlrpc/client"
require 'time'
require 'date'
require 'securerandom'
# container_operations
cont_op = XMLRPCImageTest.new(ENV['TESTHOST'])
# retrieve minion id, needed for scheduleImageBuild call
def retrieve_minion_id
  sysrpc = XMLRPCSystemTest.new(ENV['TESTHOST'])
  sysrpc.login('admin', 'admin')
  systems = sysrpc.listSystems
  refute_nil(systems)
  minion_id = systems
              .select { |s| s['name'] == $minion_fullhostname }
              .map { |s| s['id'] }.first
  refute_nil(minion_id, "Minion #{$minion_fullhostname} is not yet registered?")
  minion_id
end

And(/^I select sle-minion hostname in Build Host$/) do
  select($minion_fullhostname, :from => 'host')
end

And(/^I navigate to images webpage$/) do
  visit("https://#{$server_fullhostname}/rhn/manager/cm/images")
end

And(/^I navigate to images build webpage$/) do
  visit("https://#{$server_fullhostname}/rhn/manager/cm/build")
end

And(/^I verify that all "([^"]*)" container images were built correctly in the gui$/) do |count|
  20.times do
    raise "error detected while building images" if has_xpath?("//*[contains(@title, 'Failed')]")
    break if has_xpath?("//*[contains(@title, 'Built')]", :count => count)
    sleep 20
    step %(I navigate to images webpage)
  end
  raise "an image was not built correctly" unless has_xpath?("//*[contains(@title, 'Built')]", :count => count)
end

And(/^I schedule the build of image "([^"]*)" via xmlrpc-call$/) do |image|
  cont_op.login('admin', 'admin')
  # empty by default
  version_build = ''
  build_hostid = retrieve_minion_id
  now = DateTime.now
  date_build = XMLRPC::DateTime.new(now.year, now.month, now.day, now.hour, now.min, now.sec)
  cont_op.scheduleImageBuild(image, version_build, build_hostid, date_build)
end

And(/^I schedule the build of image "([^"]*)" with version "([^"]*)" via xmlrpc-call$/) do |image, version|
  cont_op.login('admin', 'admin')
  # empty by default
  version_build = version
  build_hostid = retrieve_minion_id
  now = DateTime.now
  date_build = XMLRPC::DateTime.new(now.year, now.month, now.day, now.hour, now.min, now.sec)
  cont_op.scheduleImageBuild(image, version_build, build_hostid, date_build)
end

And(/^I delete the image "([^"]*)" with version "([^"]*)" via xmlrpc-call$/) do |image_name_todel, version|
  cont_op.login('admin', 'admin')
  images_list = cont_op.listImages
  refute_nil(images_list, "ERROR: no images at all were retrieved.")
  images_list.each do |element|
    if element['name'] == image_name_todel.strip && element['version'] == version.strip
      $image_id = element['id']
    end
  end
  cont_op.deleteImage($image_id)
end

And(/^The image "([^"]*)" with version "([^"]*)" doesn't exist via xmlrpc-call$/) do |image_non_exist, version|
  cont_op.login('admin', 'admin')
  images_list = cont_op.listImages
  images_list.each do |element|
    raise "#{image_non_exist} should not exist anymore" if element['name'] == image_non_exist && element['version'] == version.strip
  end
end

# images stores tests
And(/^I run image.store tests via xmlrpc$/) do
  cont_op.login('admin', 'admin')
  # Test create and delete calls
  # create and delete a store, even with invalid uri.
  cont_op.createStore('fake_store', 'https://github.com/SUSE/spacewalk-testsuite-base', 'registry')
  cont_op.deleteStore('fake_store')
  # test list images and list image types call
  store_typ = cont_op.listImageStoreTypes
  assert_equal(store_typ.length, 1, 'we have only type support for Registry! New method added?! please update the tests')
  assert_equal(store_typ[0]['label'], 'registry', 'imagestore label type should be registry!')
  registry_list = cont_op.listImageStores
  # print just for debug
  puts registry_list
  assert_equal(registry_list[0]['label'], 'galaxy-registry', 'label is galaxy!')
  assert_equal(registry_list[0]['uri'], 'registry.mgr.suse.de', 'uri should be registry.mgr.suse.de')
  # test setDetails call
  # delete if test fail in the middle. delete image doesn't raise an error if image doesn't exists
  cont_op.createStore('Norimberga', 'https://github.com/SUSE/spacewalk-testsuite-base', 'registry')
  details_store = {}
  details_store['uri'] = 'Germania'
  details_store['username'] = ''
  details_store['password'] = ''
  cont_op.setDetails('Norimberga', details_store)
  # test getDetails call
  details = cont_op.getDetailsStore('Norimberga')
  assert_equal(details['uri'], 'Germania', 'uri should be Germania')
  assert_equal(details['username'], '', 'username should be empty')
  cont_op.deleteStore('Norimberga')
end

And(/^I create "([^"]*)" random image stores$/) do |count|
  cont_op.login('admin', 'admin')
  $labels = []
  count.to_i.times do
    label = SecureRandom.urlsafe_base64(10)
    $labels.push(label)
    uri = SecureRandom.urlsafe_base64(13)
    cont_op.createStore(label, uri, 'registry')
  end
end

And(/^I delete the random image stores$/) do
  cont_op.login('admin', 'admin')
  $labels.each do |label|
    cont_op.deleteStore(label)
  end
end
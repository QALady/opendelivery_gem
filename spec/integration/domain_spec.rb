require File.expand_path('../../spec_helper', __FILE__)
require 'aws-sdk'

describe OpenDelivery::Domain do

  context 'Specifying region', slow: true do
    before(:each) do
      @domain_name = 'opendeliverytest_domain_1'
      @domain_under_test = OpenDelivery::Domain.new('us-west-1')
      @sdb = AWS::SimpleDB.new(:region => 'us-west-1')
    end

    describe 'create domain' do
      it 'should be able to create a domain in another region' do
        @domain_under_test.create(@domain_name)
        @sdb.domains[@domain_name].exists?.should eql true
      end
    end

    describe 'Delete domain' do
      it 'should be able to delete a domain in another region' do

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end

        @domain_under_test.destroy(@domain_name)
        @sdb.domains[@domain_name].exists?.should eql false
      end
    end

    after(:each) do
      # puts "\n============= RUNNING THE AFTER BLOCK ================"
      AWS::SimpleDB.consistent_reads do
        @sdb.domains[@domain_name].delete!
      end
    end
  end

  context 'Load Domain', slow: true do
    before(:each) do
      @domain_name = 'opendeliverytest-domain'
      @domain_under_test = OpenDelivery::Domain.new('us-west-1')
      @encrypted_domain = OpenDelivery::Domain.new('us-west-1','spec/private.pem')

      @sdb = AWS::SimpleDB.new(:region => 'us-west-1')
      AWS::SimpleDB.consistent_reads do
        @sdb.domains.create(@domain_name)
        until @sdb.domains[@domain_name].exists?
          sleep 1
        end
      end
      @filename = 'temp.json'
      File.open(@filename, 'w') {|f| f.write('{  "test": { "testFieldOne" : "testValueOne", "testFieldTwo" : "testValueTwoA" }}') }
    end


    describe 'Load Domain' do
      it 'should load the json file entries into the domain' do
        @domain_under_test.load_domain(@domain_name, @filename)

        actual_value = @domain_under_test.get_property(@domain_name, 'test', 'testFieldOne')
        actual_value.should eql 'testValueOne'

        actual_value = @domain_under_test.get_property(@domain_name, 'test', 'testFieldTwo')
        actual_value.should eql 'testValueTwoA'
      end
    end


    after(:each) do
      AWS::SimpleDB.consistent_reads do
        @sdb.domains[@domain_name].delete!
      end

      if File.exists? @filename then File.delete @filename end

    end
  end


  context 'Not specifying region', slow: true do

    before(:each) do
      @domain_name = 'opendeliverytest_domain_2'
      @domain_under_test = OpenDelivery::Domain.new
      @encrypted_domain = OpenDelivery::Domain.new(nil,'spec/private.pem')
      @sdb = AWS::SimpleDB.new
    end

    describe 'create domain' do
      it 'should be able to create a domain' do
        @domain_under_test.create(@domain_name)
      end
    end

     describe 'Delete domain' do
      it 'should be able to create a domain in another region' do

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end

        @domain_under_test.destroy(@domain_name)
        @sdb.domains[@domain_name].exists?.should eql false
      end
    end

    describe 'destroy item' do

      before(:each) do
        @item_name = 'item_name'
        @key = 'test_key_1'
        @expected_value = 'test_value_1'

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end

        @sdb.domains[@domain_name].items.create(@item_name, { @key => @expected_value } )
      end

      it 'should destroy the item' do
        @domain_under_test.destroy_item(@domain_name, @item_name)
        # Sleep briefly because sometimes this fails.
        sleep 0.5
        AWS::SimpleDB.consistent_reads do
          domain = @sdb.domains[@domain_name]
          items = domain.items
          items.size.should eql 0
        end
      end

    end

    describe 'get property' do

      before(:each) do
        @item_name = 'item_name'
        @key = 'test_key_1'
        @key4 = 'test_key_4'
        @expected_value = 'test_value_1'
        @expected_value4 = 'test_value_4'

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end

        @sdb.domains[@domain_name].items.create(@item_name, { @key => @expected_value } )
        @encrypted_domain.set_encrypted_property(@domain_name, @item_name, @key4, @expected_value4)

      end

      it 'should return the proper value for the specified key' do
        actual_value = @domain_under_test.get_property(@domain_name, @item_name, @key)
        actual_value.should eql @expected_value
      end

      it 'should return the nil value for the missing key' do
        actual_value = @domain_under_test.get_property(@domain_name, @item_name, 'bad_key')
        actual_value.should eql nil
      end

      it 'should return the nil value for the missing item' do
        actual_value = @domain_under_test.get_property(@domain_name, 'bad_item', 'bad_key')
        actual_value.should eql nil
      end

      it 'should find a decrypted property' do
        actual_value = @encrypted_domain.get_encrypted_property(@domain_name, @item_name, @key4)
        actual_value.should eql @expected_value4
      end

      it 'should find an encrypted property' do
        actual_value = @encrypted_domain.get_property(@domain_name, @item_name, @key4)
        actual_value.should_not eql @expected_value4
      end
    end

    describe 'get item attributes json' do

      before(:each) do
        @item_name = 'item_name'
        @keys = { 'test_key_1' => 'test_value_1', 'test_key_4' => 'test_value_4' }
        @expected_value = '[{"name":"test_key_4","value":"test_value_4"},{"name":"test_key_1","value":"test_value_1"}]'

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end

        @sdb.domains[@domain_name].items.create(@item_name, @keys)
      end

      it 'should return the proper values for the specified item' do
        actual_value = @domain_under_test.get_item_attributes_json(@domain_name, @item_name)
        actual_value.should eql @expected_value
      end

      it 'should return the nil value for the missing item' do
        actual_value = @domain_under_test.get_item_attributes_json(@domain_name, 'bad_item')
        actual_value.should eql nil
      end
    end

    describe 'set property' do

      before(:each) do
        @item_name = 'item_name'
        @key = 'test_key_1'
        @expected_value = 'test_value_1'

        AWS::SimpleDB.consistent_reads do
          @sdb.domains.create(@domain_name)
          until @sdb.domains[@domain_name].exists?
            sleep 1
          end
        end
      end

      it 'should set the specified value for the specified key' do
        @domain_under_test.set_property(@domain_name, @item_name, @key, @expected_value)

        AWS::SimpleDB.consistent_reads do
          actual_value = @sdb.domains[@domain_name].items[@item_name].attributes[@key].values[0].chomp
          actual_value.should eql @expected_value
        end
      end

      it 'should set the value for the key to only a single value' do
        @domain_under_test.set_property(@domain_name, @item_name, @key, @expected_value)
        AWS::SimpleDB.consistent_reads do
          actual_value = @sdb.domains[@domain_name].items[@item_name].attributes[@key].values[0].chomp
          actual_value.should eql @expected_value
        end

        @domain_under_test.set_property(@domain_name, @item_name, @key, @expected_value)
        AWS::SimpleDB.consistent_reads do
          actual_value = @sdb.domains[@domain_name].items[@item_name].attributes[@key].values[0].chomp
          actual_value.should eql @expected_value
          @sdb.domains[@domain_name].items[@item_name].attributes[@key].values.size.should eql 1
        end
      end
    end
    after(:each) do
     # puts "\n============= RUNNING THE AFTER BLOCK ================"
      AWS::SimpleDB.consistent_reads do
        @sdb.domains[@domain_name].delete!
      end
    end
  end
end

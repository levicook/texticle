require "test/unit"
require 'texticle'
require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require 'test'

def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end

ActiveRecord::Base.extend(Texticle)

begin
  ActiveRecord::Base.establish_connection({
    :adapter   => 'postgresql',
    :database  => 'texticle_test',
    # :encoding => 'unicode',
    :host      => '127.0.0.1',
    :username  => 'texticle',
    :password  => 'secret',
  }) 
rescue
  $stderr.puts 'Have you run "createdb texticle_test && createuser -PE texticle"'
  raise $!
end


def create_table
  unless ActiveRecord::Base.connection.table_exists?(:accounts)
    ActiveRecord::Base.connection.create_table(:accounts) do |t|
      t.column :fname, :string
      t.column :lname, :string
    end
  end
end

def drop_table
  ActiveRecord::Base.connection.drop_table(:accounts)
end

ActiveRecord::Base.module_eval do
  def to_sql(options={})
    construct_finder_sql(options)
  end
end

class Account < ActiveRecord::Base
  index 'name' do
    fname 'A'
    lname 'B'
  end
  index 'fname' do
    fname
  end
  index 'lname' do
    lname
  end
end

class TestTexticleAndActiveRecord < Test::Unit::TestCase
  def setup
    drop_table
    silence_stream($stderr) { create_table }
    assert_equal true, ActiveRecord::Base.connection.table_exists?(:accounts)
    @a1 = Account.create :fname => 'Bart',  :lname => 'Simpson'
    @a2 = Account.create :fname => 'Black', :lname => 'Bart'
  end

  def test_search_name_bart
    results = Account.search_name('Bart')
    assert_equal @a1, results.first
    assert_equal @a2, results.last
    assert_equal 2, results.length
  end
  def test_search_name_simpson
    results = Account.search_name('Simpson')
    assert_equal @a1, results.first
    assert_equal 1, results.length
  end
  def test_search_name_black
    results = Account.search_name('Black')
    assert_equal @a2, results.first
    assert_equal 1, results.length
  end

  def test_search_fname_bart
    results = Account.search_fname('Bart')
    assert_equal @a1, results.first
    assert_equal 1, results.length
  end
  def test_search_fname_black
    results = Account.search_fname('Black')
    assert_equal @a2, results.first
    assert_equal 1, results.length
  end
  def test_search_fname_simpson
    results = Account.search_fname('Simpson')
    assert_equal 0, results.length
  end

  def test_search_lname_simpson
    results = Account.search_lname('Simpson')
    assert_equal @a1, results.first
    assert_equal 1, results.length
  end
  def test_search_lname_bart
    results = Account.search_lname('Bart')
    assert_equal @a2, results.first
    assert_equal 1, results.length
  end
  def test_search_lname_black
    results = Account.search_fname('Black')
    assert_equal 0, results.length
  end
end

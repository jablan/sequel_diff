require 'sinatra'
require 'haml'
require 'json'
require 'sequel'

DB = Sequel.connect 'postgres://test:test@localhost/test'

def diff params

  contents = [@table_left, @table_right].map{ |table|
    DB[table.to_sym].filter(@conditions).inject({}){ |acc, rec|
      # convert strings to symbols:
      h = Hash[rec.map{ |k,v|
        if v.is_a? String
          [k, v.to_sym]
        else
          [k, v]
        end
      }]

      keys = h.values_at(*@key_cols)
      acc[keys] ||= [0]*@val_cols.count
      @val_cols.each_with_index do |c, i|
        acc[keys][i] += h[c]
      end
      acc
    }
  }
#  p contents

  @title = "#{@table_left} vs. #{@table_right}"
  @left, @right = contents

  @common_keys = (@left.keys & @right.keys).sort
  by_sameness = @common_keys.group_by{|key|
    @left[key] == @right[key]
  }
  @same_values = by_sameness[true] || []
  @diff_values = by_sameness[false] || []
  @in_left_only = (@left.keys - @right.keys).sort
  @in_right_only = (@right.keys - @left.keys).sort
end

get '/' do
  @tables = DB.tables
  @tables += DB.views if DB.respond_to?(:views)
  @tables.sort!
  @title = 'Pick tables to compare'
  if params['left'] && params['right']
    @table_left = params['left'].to_sym
    @table_right = params['right'].to_sym

    @cols = Hash[params["col_type"].
      group_by{|k,v| v}.
      map{|k,v| [k.to_sym, v.map{|k1,_| k1.to_sym}]}
    ]
  #  return "Key columns don't match in left and right" unless @cols[0][:key] == @cols[1][:key]
  #  return "Value columns don't match in left and right" unless @cols[0][:value] == @cols[1][:value]
    @key_cols = @cols[:key] || []
    @val_cols = @cols[:value] || []
    @conditions = params['conditions'].strip
    @conditions = {} if @conditions.empty?
    diff(params)
  end
  haml :main
end

get '/columns/:left/:right' do |left, right|
  @col_type = params['col_type'] || {}
  @left = DB[left.to_sym].columns
  @right = DB[right.to_sym].columns

  @common = @left & @right
  @left -= @common
  @right -= @common
  haml :columns, :layout => false
end

get '/diff' do
  diff params
#  @cols.inspect
end


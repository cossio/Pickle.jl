import Base: setindex!, haskey, getindex

struct TableBlock
  depth::Int
  entry::Dict{String, Union{TableBlock, Some}}
end

TableBlock() = TableBlock(0)
TableBlock(depth) = TableBlock(depth, Dict())

@inline haskey(tb::TableBlock, x) = haskey(tb.entry, x)

function setindex!(tb::TableBlock, value::Some, key; maxdepth=typemax(Int))
  (haskey(tb, key) || !any(isequal('.'), key) || tb.depth >= maxdepth) &&
    return setindex!(tb.entry, value, key)

  scope, id = split(key, '.'; limit=2)

  ctb = haskey(tb, scope) ? tb.entry[scope] : begin
    _ctb = TableBlock(tb.depth+1)
    setindex!(tb.entry, _ctb, scope)
    _ctb
  end
  return setindex!(ctb, value, id)
end

function getindex(tb::TableBlock, key; maxdepth=typemax(Int), error=false)
  (haskey(tb, key) || !any(isequal('.'), key) || tb.depth >= maxdepth) &&
    (error ? (return getindex(tb.entry, key)) : (return get(tb.entry, key, nothing)))

  scope, id = split(key, '.'; limit=2)

  !haskey(tb, scope) ? (error ? throw(KeyError(scope)) : return nothing) : return getindex(tb.entry[scope], id)
end

struct HierarchicalTable
  maxdepth::Int
  head::TableBlock
end

HierarchicalTable() = HierarchicalTable(typemax(Int))
HierarchicalTable(maxdepth) = HierarchicalTable(maxdepth, TableBlock())

setindex!(ht::HierarchicalTable, value, key) = setindex!(ht.head, Some(value), key; maxdepth=ht.maxdepth)

getindex(ht::HierarchicalTable, key) = something(getindex(ht.head, key; maxdepth=ht.maxdepth, error=false))

haskey(ht::HierarchicalTable, key) = !isnothing(getindex(ht.head, key))

const GLOBAL_MT = HierarchicalTable()

function lookup(mt::HierarchicalTable, scope, name)
  global GLOBAL_MT
  key = join((scope, name), '.')
  mtv = getindex(mt.head, key)
  if isnothing(mtv)
    gmtv = getindex(GLOBAL_MT.head, key)
    return isnothing(gmtv) ? gmtv : something(gmtv)
  else
    return something(mtv)
  end
end

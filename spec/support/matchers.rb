require 'rspec/expectations'

def get_subquire quire_struct, subquire_num
  return quire_struct.top if subquire_num == :top
  quire_struct.subquire subquire_num
end

def same_subquire_num? first, second
  return true if first == second
  [first, second].all? { |num| [0, :top].include? num }
end

##
# Build and test the QuireStructure for `subquire_num`, where subquire is an
# integer or `:top` for the top level quire (which is subquire number 0)
RSpec::Matchers.define :have_subquire_with_balanced_conjoins do |subquire_num|
  match do |quire_struct|
    quire_struct.build
    subquire = get_subquire quire_struct, subquire_num
    expect(subquire).to have_balanced_conjoins
  end
end

##
# Ensure the Subquire has balance conjoins
RSpec::Matchers.define :have_balanced_conjoins do
  match do |subquire|
    slots = subquire.super_structure.slots
    slots.size.times { |i| expect(slots[i].conjoin).to eq slots[-1 - i] }
  end
  failure_message do |actual|
    # binding.pry
    "expected that #{actual.super_structure.slots} would have balanced conjoins"
  end
end

##
# Build and test the QuireStructure for `subquire_num`, where subquire is an
# integer or `:top` for the top level quire (which is subquire number 0)
RSpec::Matchers.define :have_subquire_with_balanced_substructure do |subquire_num|
  match do |quire_struct|
    quire_struct.build
    subquire = get_subquire quire_struct, subquire_num
    expect(subquire).to have_balanced_substructure
  end
end

##
# Ensure the Subquire has balanced conjoins in its substructure.
RSpec::Matchers.define :have_substructure_size do |size|
  match do |subquire|
    expect(subquire.substructure.size).to eq size
  end
  failure_message do |actual|
    "expected that Subquire #{subquire} would have size #{size}; got #{actual}"
  end
end

##
# Build and test the QuireStructure for `subquire_num`, where subquire is an
# integer or `:top` for the top level quire (which is subquire number 0)
RSpec::Matchers.define :have_subquire_with_substructure_size do |subquire_num, size|
  match do |quire_struct|
    quire_struct.build
    subquire = get_subquire quire_struct, subquire_num
    expect(subquire).to have_substructure_size size
  end
end

##
# Ensure the Subquire has balanced conjoins in its substructure.
RSpec::Matchers.define :have_balanced_substructure do
  match do |subquire|
    slots = subquire.substructure.slots
    slots.size.times { |i| expect(slots[i].conjoin).to eq slots[-1 - i] }
  end
  failure_message do |actual|
    "expected that #{actual} would have balanced conjoins"
  end
end

##
# Build and test the QuireStructure for `subquire_num`, where subquire is an
# integer or `:top` for the top level quire (which is also subquire number 1)
#
# `posns` is an array of arrays of 1-based positions within the array of
# QuireSlot objects. 1-based positions are used to keep consistency with the
# 1-based XML expression of each leave's position within a quire.
RSpec::Matchers.define :have_subquire_with_conjoin_positions do |subquire_num, posns|
  match do |quire_struct|
    quire_struct.build
    subquire = get_subquire quire_struct, subquire_num
    expect(subquire).to have_conjoin_positions posns
  end
end

##
# `posns` is an array of arrays of 1-based positions within the array of
# QuireSlot objects. 1-based positions are used to keep consistency with the
# 1-based XML expression of each leave's position within a quire.
RSpec::Matchers.define :have_conjoin_positions do |posns|
  match do |subquire|
    ra = posns.first.respond_to?(:first) ? posns : [posns]
    ra.each do |pair|
      slots = subquire.super_structure.slots
      slot1 = slots[pair.first - 1]
      slot2 = slots[pair.last - 1]
      expect(slot1.conjoin).to eq slot2
      # make sure reciprocal works too
      expect(slot2.conjoin).to eq slot1
    end
  end
  failure_message do |actual|
    slots = actual.super_structure.slots
    "expected that #{slots[position - 1]} would be conjoin with #{slots[conjoin_position - 1]}"
  end
end

##
# Build and test the QuireStructure for adjacent subquires, where `first` and
# `second` are integers for the subquire numbers, or `:top` for the top level
# subquire.
#
RSpec::Matchers.define :have_adjacent_subquires do |first, second|
  match do |quire_struct|
    raise "Can't compare subquire to self" if same_subquire_num? first, second

    quire_struct.build
    sq1 = get_subquire quire_struct, first
    sq2 = get_subquire quire_struct, second
    expect(sq1.super_structure.adjacent?(sq2.super_structure)).to be true
  end
end

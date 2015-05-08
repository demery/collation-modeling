require 'ostruct'

class Quire < ActiveRecord::Base
  attr_accessor :leaf_count_input

  belongs_to :manuscript
  has_many :leaves, -> { order('position ASC') }, dependent: :destroy
  accepts_nested_attributes_for :leaves, allow_destroy: true

  before_save :create_leaves

  validate :must_have_even_bifolia

  acts_as_list scope: :manuscript

  def name
    sprintf "%s  Quire %s", manuscript.title, number
  end

  def next
    lower_item
  end

  def previous
    higher_item
  end

  def to_struct
    OpenStruct.new n: position, units: units
  end

  # Return a list of leaves with conjoins, filling in `nil` leaf
  # placeholders for the partners of single leaves.  For example:
  #
  # leaf n=1,   mode="original", folio_number="1", conjoin=8,   position=1
  # leaf n=2,   mode="original", folio_number="2", conjoin=nil, position=2
  # leaf n=3,   mode="original", folio_number="3", conjoin=7,   position=3
  # leaf n=nil,                                    conjoin=6,   position=4
  # leaf n=4,   mode="original", folio_number="4", conjoin=5,   position=5
  # leaf n=5,   mode="original", folio_number="5", conjoin=4,   position=6
  # leaf n=6,   mode="original", folio_number="6", conjoin=nil, position=7
  # leaf n=7,   mode="original", folio_number="7", conjoin=3,   position=8
  # leaf n=nil,                                    conjoin=2,   position=9
  # leaf n=8,   mode="original", folio_number="8", conjoin=1,   position=10
  #
  # This presentation is a convenience for building quire diagrams
  # where single leaves are balanced with blank slots.
  def filled_quire
    leaves = to_leaves
    if !has_conjoins? leaves
      handle_all_singles leaves
    else
      to_leaves.each do |leaf|
        if leaf.conjoin.nil?
          insert_single_join leaves, leaf
        end
      end
    end
    leaves.each_with_index { |leaf,index| leaf.position = (index+1) }
    leaves
  end

  # Return +true+ if +leaves+ has at least one conjoin pair.
  def has_conjoins? leaves
    leaves.any? { |leaf| leaf.conjoin.present? }
  end

  # For a quire of all single leaves, add conjoin placeholders
  # at the end. So, the following:
  #
  #   n=1 - join=
  #   n=2 - join=
  #
  # Becomes:
  #
  #   n=1 - join=
  #   n=2 - join=
  #   n=  - join=2
  #   n=  - join=1
  #
  def handle_all_singles leaves
    leaves.reverse!
    to_leaves.reverse.each do |leaf|
      leaves.unshift OpenStruct.new(n: nil, conjoin: leaf.n)
    end
    leaves.reverse!
    leaves
  end

  # Insert a placeholder join for +single+ in +leaves+.
  #
  # We find the place to insert the single's placeholder conjoin by
  # looking for a skip in the conjoin numbers.
  #
  # A regular quire is like this:
  #
  #   n=1 - join=8
  #   n=2 - join=7
  #   n=3 - join=6
  #   n=4 - join=5
  #   n=5 - join=4
  #   n=6 - join=3
  #   n=7 - join=2
  #   n=8 - join=1
  #
  # The join numbers move in steps of one from 8 to 1.
  #
  # When there is a single leaf, the joins will skip a number, at the
  # point where +single+'s join would be. Thus:
  #
  #   n=1 - join=7
  #   n=2 - join=
  #   n=3 - join=6
  #   n=4 - join=5
  #   n=5 - join=4
  #   n=6 - join=3
  #   n=7 - join=1
  #
  # The numbering skips a step from +join=1+ to +join=3+. We assume that
  # +n=2+ should have its placeholder between 1 and 3.  And thus we
  # insert the placeholder between n=6 and n=7.
  #
  # When the single leaf or a run of single leaves is at the end or
  # the beginning of the list there is no skip in the join counting:
  #
  #   n=1 - join=
  #   n=2 - join=
  #   n=3 - join=8
  #   n=4 - join=7
  #   n=5 - join=6
  #   n=6 - join=5
  #   n=7 - join=4
  #   n=8 - join=3
  #
  # In this case, we insert the placeholders at the end of the list.
  # The default insertion point is always 0. When searching for the
  # join position we start at the end or beginng of the list.  In this
  # case, where the single leaves are before the midpoint, we reverse
  # the list and start searching from +n=8 join=3+.  If the single
  # leaves were at the end of the list, we would begin searching at
  # beginning of the list.
  #
  # Because we reverse the list for a single toward the end of the
  # list, the default insertion point is always 0.  The insertions
  # occur in two steps:
  #
  # In the first pass, no skip is found so, the placeholder joined
  # to n=1 is inserted in the last position (that is the 0 position
  # in the list while it is reversed.
  #
  #   n=1 - join=
  #   n=2 - join=
  #   n=3 - join=8
  #   n=4 - join=7
  #   n=5 - join=6
  #   n=6 - join=5
  #   n=7 - join=4
  #   n=8 - join=3
  #   n=  - join=1
  #
  # In the second pass, the a skip is found between join=1 and
  # join=3 and the placeholder join for n=2 is inserted between the
  # last and next-to-last leaves:
  #
  #   n=1 - join=
  #   n=2 - join=
  #   n=3 - join=8
  #   n=4 - join=7
  #   n=5 - join=6
  #   n=6 - join=5
  #   n=7 - join=4
  #   n=8 - join=3
  #   n=  - join=2
  #   n=  - join=1
  #
  # If the single leaves are at the end of the list, as below, the
  # insertions occur differently.
  #
  #   n=1 - join=6
  #   n=2 - join=5
  #   n=3 - join=4
  #   n=4 - join=3
  #   n=5 - join=2
  #   n=6 - join=1
  #   n=7 - join=
  #   n=8 - join=
  #
  #  In the first pass, +n=7+ is handled. It is past the midpoint, so
  #  the list is not reversed. As no gap is found in the join
  #  numbering, the placeholder leaf is inserted a position +0+:
  #
  #   n=  - join=7
  #   n=1 - join=6
  #   n=2 - join=5
  #   n=3 - join=4
  #   n=4 - join=3
  #   n=5 - join=2
  #   n=6 - join=1
  #   n=7 - join=
  #   n=8 - join=
  #
  # When the second pass happens with +n=8+, no gap is found in the
  # numbering and the placeholder is again inserted at position +0+:
  #
  #   n=  - join=8
  #   n=  - join=7
  #   n=1 - join=6
  #   n=2 - join=5
  #   n=3 - join=4
  #   n=4 - join=3
  #   n=5 - join=2
  #   n=6 - join=1
  #   n=7 - join=
  #   n=8 - join=
  #
  def insert_single_join leaves, single
    # find out how many positions there are
    position = leaves.index(single) + 1

    # if the position is less than the midpoint, we reverse and search
    # for the insertion point back to front
    reverse = position < leaves.size/2
    leaves.reverse! if reverse

    # We also need to find the first or last conjoin number +/-1. If we've
    # reversed the offset is -1; otherwise, +1
    offset = reverse ? 1 : -1
    last_cj_leaf = leaves.find { |lf| lf.conjoin.present? }
    # find the first conjoin and apply the offset
    last_cj = last_cj_leaf.conjoin + offset

    # the default insertion point is always 0
    insertion_point = 0

    # We find the place to insert the single's placeholder conjoin by
    # looking for a skip in the conjoin numbers
    leaves.each_with_index do |leaf,index|
      if leaf.conjoin.blank?
        # We ignore single leaves
      else
        # the leaf is conjoin;
        #
        # If the step between this and the previous leaves' conjoins is
        # greater than 1, then we've found the skip
        if (leaf.conjoin - last_cj).abs > 1
          insertion_point = index
          break
        else
          # no skip; update last_cj
          last_cj = leaf.conjoin
        end
      end
    end
    # insert the placeholder leaf at insertion_point
    leaves.insert insertion_point, OpenStruct.new(n: nil, conjoin: single.n)
    # un-reverse the leaves if needed
    leaves.reverse! if reverse
    leaves
  end

  def to_leaves
    leaves = []
    units.each do |unit|
      first = unit.leaves.first
      if unit.leaves.size > 1
        second = unit.leaves.second
        leaves << OpenStruct.new(first.marshal_dump.merge({ conjoin: second.n }))
        leaves << OpenStruct.new(second.marshal_dump.merge({ conjoin: first.n }))
      else
        leaves << OpenStruct.new(first.marshal_dump.merge({ conjoin: nil  }))
      end
    end
    leaves.sort_by &:n
  end

  # Create a list of units. Each unit corresponds to a single leaf or
  # conjoin and thus contains either one or two leaves.
  def units
    units = []
    leaf_queue = leaves.map(&:itself)
    logger.info leaf_queue.inspect
    while leaf_queue.size > 0 do
      leaf = leaf_queue.shift.to_struct
      if leaf.single
        units << OpenStruct.new(leaves: [ leaf ])
      else
        while leaf_queue.last && leaf_queue.last.single
          units << OpenStruct.new(leaves: [ leaf_queue.pop.to_struct ])
        end
        units << OpenStruct.new(leaves: [ leaf, leaf_queue.pop.to_struct ])
      end
    end
    units.sort_by! { |u| u.leaves.first.n }
    units
  end

  private

  def create_leaves
    if leaf_count_input && leaves.blank?
      curr_folio = prev_folio_number
      leaf_count_input.to_i.times do
        curr_folio = inc_folio curr_folio
        leaves.build folio_number: curr_folio
      end
    end
  end

  # Make sure that the number of leaves not marked 'single' is even.
  def must_have_even_bifolia
    conjoins = leaves.reject{ |leaf| leaf.single? }.size
    if conjoins.odd?
      errors.add(:base, "The number of non-single leaves cannot be odd; found: #{conjoins}")
    end
  end

  # Increment the folio number. If +number+ cannot be parsed as in Integer,
  # return +nil+.
  #
  # TODO: Enable incrementing of paginated numbers, 1-2, 3-4, etc.
  #
  def inc_folio number
    begin
      Integer(number) + 1
    rescue ArgumentError, TypeError
      # if number is nil, TypeError is raised
      # if number is not an integer, ArgumentError is raised
      # in either case, return nil
      nil
    end
  end

  def prev_folio_number
    if previous.present?
      previous.leaves.last.folio_number.to_i
    else
      0
    end
  end
end

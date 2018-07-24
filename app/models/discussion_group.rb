class DiscussionGroup < ApplicationRecord
  belongs_to :largeGroup
  has_many :memberDgs
  
  # Validations
  validate :name_is_leaders_name

  # Scopes
  scope :for_lg ->(lg) { where(largeGroup: lg) }
  scope :for_name, ->(name) { where(name: name) }
  scope :alphabetical, -> { order("name") }
  scope :for_gender, -> (gender) { where(Member.find_by(name: self.name).gender == gender}

  # Functions
  def name_is_leaders_name
    if !(self.name in Member.all.for_leader)
      errors.add(self.name, "is not the name of a leader")
    end
  end

  # initialize the discussion groups per cell group; distribute the unassociated members to appropriate dgs
  def initialize_dgs(large_group)
    # create dgs
    Member.all.for_leader.each do |m|
      @dg = DiscussionGroup.create(name: m.name, largeGroup: large_group)
      m.cellGroup.members do |m|
        MemberDgs.create(member: m, discussionGroup: @dg, attended: false)
      end
    end
    # assign the other members
    male_dgs = DiscussionGroup.all.shuffle.for_gender("male")
    female_dgs = DiscussionGroup.all.shuffle.for_gender("female")
    other_members = Member.all.no_cg

    other_members.each do |m|
      # "restock" dgs to assign
      if male_dgs.empty?
        male_dgs = DiscussionGroup.all.shuffle.for_gender("male")
      elsif female_dgs.empty?
        female_dgs = DiscussionGroup.all.shuffle.for_gender("female")
      end

      # assign by gender
      if m.gender == "male"
        MemberDgs.create(member: m, discussionGroup: male_dgs.first, attended: false)
        male_dgs.delete(male_dgs.first)
      else 
        MemberDgs.create(member: m, discussionGroup: female_dgs.first, attended: false)
        male_dgs.delete(female_dgs.first)
      end
  end

  # randomize the members of cell groups
  def randomize
    array_1 = []
    array_2 = []
    dgs = DiscussionGroup.all.alphabetical

    # shuffle each initial discussion group (cell group) and split into 2 halves
    dgs.each do |dg|
      randomized = dg.memberDgs.shuffle
      parts = randomized.size / 2
      split_groups = randomized.each_slice(parts)
      array_1.push(split_groups[0])
      array_2.push(split_groups[1])
    end
    
    # rename so can be redone if messes up
    group_1 = array_1
    group_2 = array_2.shuffle

    # compare first two dg halves to match
    dgs.each do |dg|
      dg_1 = group_1[0] # array of MDGs
      dg_2 = group_2[0]

      # "reshuffle" if both dgs halves are from the same dg
      if dg.name == dg_2[0].discussionGroup.name
        if group_1.size > 1 
          dg_2 = group_2[1]
        else # if last 2 halves are the same cell group, reshuffle entirely
          group_1 = array_1
          group_2 = array_2.shuffle
          puts "Going to retry and see if it works"
          retry
        end
      end

      # update dg_2 by reassigning to new dg
      dg_2.each do |mdg|
        mdg.update_attributes(:discussionGroup => dg)
      end
    end
  end
end

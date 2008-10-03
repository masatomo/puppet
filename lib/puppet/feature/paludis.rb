#  Created by Luke Kanies on 2006-04-30.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/util/feature'

# We've got the Paludis library  available.
Puppet.features.add(:paludis, :libs => ["Paludis"])

module VirtualBox
  module COM
    module Interface
      module Version_4_0_X
        class ChipsetType < AbstractEnum
          map [:null, :piix3, :ich9]
        end
      end
    end
  end
end

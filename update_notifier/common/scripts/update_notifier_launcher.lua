
function onInit()
    if not DB.getRoot().createChild('update_notifier').getChild('bmosaurawishlist') then
        Interface.openWindow('update_notifier', DB.getRoot().createChild('update_notifier'))
    end
end

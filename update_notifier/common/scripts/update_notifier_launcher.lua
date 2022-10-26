function onInit()
    local nodeUpdateNotifier = DB.getRoot().createChild('update_notifier')
    if nodeUpdateNotifier and not nodeUpdateNotifier.getChild('bmosaurawishlist') then
        Interface.openWindow('update_notifier', nodeUpdateNotifier)
    end
end
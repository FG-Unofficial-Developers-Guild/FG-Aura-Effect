function onInit()
    local nodeUpdateNotifier = DB.getRoot().createChild('update_notifier')
    if Session.IsHost and nodeUpdateNotifier and not nodeUpdateNotifier.getChild('bmosaurawishlist') then
        Interface.openWindow('update_notifier', nodeUpdateNotifier)
    end
end
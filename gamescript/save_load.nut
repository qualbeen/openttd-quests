class SaveLoad {
    static function SaveState(gs) {
        return { version = 1 };
    }

    static function LoadState(gs, data) {
        GSLog.Info("SaveLoad.LoadState() stub");
    }
}

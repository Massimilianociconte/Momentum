import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

class RallyMateApp extends Application.AppBase {
    private var _model;
    private var _activity;
    private var _sync;
    private var _view;

    public function initialize() {
        AppBase.initialize();
        _model = new RallyMateScoreModel();
        _activity = new RallyMateActivitySession();
        _sync = new RallyMateSync(_model, _activity);
        _view = new RallyMateView(_model, _sync);

        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
    }

    (:productionNetwork)
    public function onStart(state) {
        _model.restore();
        _activity.restoreForMatch(_model);
        _sync.flush();
    }

    public function onStop(state) {
        _sync.shutdown();
        if (RallyMateActivityPolicy.shouldFinalizeOnStop(state)) {
            _activity.closeForAppExit(_model.matchId());
        }
        _model.persist();
    }

    public function getInitialView() {
        return [_view, new RallyMateDelegate(_model, _activity, _sync, _view)];
    }

    public function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        if (message != null && message.data != null) {
            var previousMatchId = _model.matchId();
            var wasStarted = _model.hasStarted();
            var wasComplete = _model.score()["complete"] == true;
            _sync.handlePhoneMessage(message.data);
            var isStarted = _model.hasStarted();
            var isComplete = _model.score()["complete"] == true;
            if (isStarted
                    && !isComplete
                    && (!wasStarted || !_model.matchId().equals(previousMatchId))) {
                _activity.startForMatch(_model.matchId());
            } else if (isComplete && !wasComplete) {
                _activity.completeForMatch(_model.matchId());
            }
            WatchUi.requestUpdate();
        }
    }
}

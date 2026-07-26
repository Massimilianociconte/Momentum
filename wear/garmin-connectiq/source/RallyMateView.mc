import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

const RM_NIGHT = 0x07101E;
const RM_PANEL = 0x111B2B;
const RM_PANEL_RAISED = 0x182438;
const RM_COURT = 0x12313B;
const RM_LIME = 0xC8F135;
const RM_LIME_DARK = 0x283713;
const RM_BLUE = 0x5AB0FF;
const RM_BLUE_DARK = 0x102A43;
const RM_TEXT_MUTED = 0x9AA7B8;
const RM_TEXT_FAINT = 0x687487;
const RM_GREEN = 0x65D66E;
const RM_AMBER = 0xF8C94D;
const RM_ORANGE = 0xFF8A45;
const RM_RED = 0xFF6262;

// One geometry source drives both drawing and hit testing. This prevents a
// visually inactive area from scoring a point on touch-screen devices.
class RallyMateLayout {
    public static function create(width, height, compact, round) {
        var margin = compact
            ? (width * 0.08).toNumber()
            : (width * (round ? 0.10 : 0.055)).toNumber();
        var gap = compact ? 5 : (width * 0.025).toNumber();
        var buttonTop = (height * (compact ? 0.55 : 0.56)).toNumber();
        var buttonHeight = (height * (compact ? 0.21 : 0.22)).toNumber();
        var fullWidth = width - (margin * 2);
        var halfWidth = ((fullWidth - gap) / 2).toNumber();
        var footerMargin = round
            ? (width * (compact ? 0.15 : 0.14)).toNumber()
            : margin;
        var footerFullWidth = width - (footerMargin * 2);
        var footerTop = (height * (round ? 0.77 : (compact ? 0.80 : 0.82))).toNumber();
        var footerHeight = (height * (round ? 0.09 : (compact ? 0.11 : 0.10))).toNumber();
        var footerHalfWidth = ((footerFullWidth - gap) / 2).toNumber();

        return {
            "margin" => margin,
            "scoreX" => margin,
            "scoreY" => (height * (compact ? 0.05 : 0.105)).toNumber(),
            "scoreW" => fullWidth,
            "scoreH" => (height * (compact ? 0.46 : 0.42)).toNumber(),
            "buttonX" => margin,
            "buttonY" => buttonTop,
            "buttonW" => fullWidth,
            "buttonH" => buttonHeight,
            "teamAX" => margin,
            "teamAW" => halfWidth,
            "teamBX" => margin + halfWidth + gap,
            "teamBW" => halfWidth,
            "footerY" => footerTop,
            "footerH" => footerHeight,
            "undoX" => footerMargin,
            "undoW" => footerHalfWidth,
            "syncX" => footerMargin + footerHalfWidth + gap,
            "syncW" => footerHalfWidth
        };
    }

    public static function actionFor(layout, x, y, assignedTeam, complete, canUndo, paused) {
        if (layout == null) {
            return null;
        }
        if (canUndo && contains(
                x,
                y,
                layout["undoX"],
                layout["footerY"],
                layout["undoW"],
                layout["footerH"]
            )) {
            return "UNDO";
        }
        if (contains(
                x,
                y,
                layout["syncX"],
                layout["footerY"],
                layout["syncW"],
                layout["footerH"]
            )) {
            return "MENU";
        }
        if (paused == true && contains(
                x,
                y,
                layout["buttonX"],
                layout["buttonY"],
                layout["buttonW"],
                layout["buttonH"]
            )) {
            return "MENU";
        }
        if (complete || paused == true) {
            return null;
        }
        if (assignedTeam != null && contains(
                x,
                y,
                layout["buttonX"],
                layout["buttonY"],
                layout["buttonW"],
                layout["buttonH"]
            )) {
            return "POINT_" + assignedTeam;
        }
        if (contains(
                x,
                y,
                layout["teamAX"],
                layout["buttonY"],
                layout["teamAW"],
                layout["buttonH"]
            )) {
            return "POINT_TEAM_A";
        }
        if (contains(
                x,
                y,
                layout["teamBX"],
                layout["buttonY"],
                layout["teamBW"],
                layout["buttonH"]
            )) {
            return "POINT_TEAM_B";
        }
        return null;
    }

    private static function contains(x, y, left, top, width, height) {
        return x >= left && x <= left + width && y >= top && y <= top + height;
    }
}

class RallyMateView extends WatchUi.View {
    private var _model;
    private var _sync;
    private var _screenHeight = 240;
    private var _layout = null;
    private var _isTouch = false;
    private var _compact = false;

    public function initialize(model, sync) {
        View.initialize();
        _model = model;
        _sync = sync;
    }

    public function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var settings = System.getDeviceSettings();
        var compact = width <= 200;
        var round = settings.screenShape == System.SCREEN_SHAPE_ROUND;
        _screenHeight = height;
        _isTouch = settings.isTouchScreen;
        _compact = compact;
        _layout = RallyMateLayout.create(width, height, compact, round);

        dc.setColor(RM_NIGHT, RM_NIGHT);
        dc.clear();
        drawScreenCourtMotif(dc, width, height, compact);

        var score = _model.score();
        if (score["complete"] == true) {
            drawComplete(dc, width, height, score, compact);
            drawFooter(dc, width, height, compact);
            return;
        }

        drawScoreCard(dc, width, height, score, compact);
        if (score["paused"] == true) {
            drawPausedControls(dc, width, height, compact);
        } else {
            drawPointControls(dc, width, height, compact);
        }
        drawFooter(dc, width, height, compact);
    }

    private function drawScreenCourtMotif(dc, width, height, compact) {
        if (compact) {
            return;
        }
        var courtWidth = (width * 0.58).toNumber();
        var courtHeight = (height * 0.72).toNumber();
        var left = ((width - courtWidth) / 2).toNumber();
        var top = ((height - courtHeight) / 2).toNumber();
        dc.setColor(0x0B2230, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(left, top, courtWidth, courtHeight, 5);
        dc.drawLine(width / 2, top, width / 2, top + courtHeight);
        dc.drawLine(left, top + courtHeight / 2, left + courtWidth, top + courtHeight / 2);
        dc.setColor(0x31451B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(
            left + (courtWidth * 0.72).toNumber(),
            top + (courtHeight * 0.72).toNumber(),
            width >= 390 ? 3 : 2
        );
    }

    public function screenHeight() {
        return _screenHeight;
    }

    public function tapAction(x, y) {
        if (!_isTouch) {
            return null;
        }
        var score = _model.score();
        return RallyMateLayout.actionFor(
            _layout,
            x,
            y,
            _model.assignedTeam(),
            score["complete"] == true,
            _model.canUndo(),
            score["paused"] == true
        );
    }

    private function drawPausedControls(dc, width, height, compact) {
        var x = _layout["buttonX"];
        var y = _layout["buttonY"];
        var buttonWidth = _layout["buttonW"];
        var buttonHeight = _layout["buttonH"];
        var radius = compact ? 9 : (buttonHeight * 0.24).toNumber();
        dc.setColor(RM_PANEL_RAISED, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, buttonWidth, buttonHeight, radius);
        dc.setColor(RM_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, buttonWidth, buttonHeight, radius);
        dc.drawText(
            width / 2,
            y + (buttonHeight * 0.18).toNumber(),
            compact ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM,
            string(Rez.Strings.Paused),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(RM_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            y + (buttonHeight * 0.64).toNumber(),
            Graphics.FONT_TINY,
            string(Rez.Strings.MenuToResume),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawScoreCard(dc, width, height, score, compact) {
        var x = _layout["scoreX"];
        var y = _layout["scoreY"];
        var cardWidth = _layout["scoreW"];
        var cardHeight = _layout["scoreH"];
        var radius = compact ? 10 : (cardHeight * 0.13).toNumber();

        dc.setColor(RM_PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, cardWidth, cardHeight, radius);
        dc.setColor(RM_PANEL_RAISED, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, cardWidth, cardHeight, radius);

        // A restrained top-view court motif gives the score card a padel
        // identity without images, animation, or extra battery work.
        if (!compact && width >= 260) {
            drawCourtMotif(dc, x, y, cardWidth, cardHeight);
        }

        dc.setColor(RM_LIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            y + (cardHeight * 0.04).toNumber(),
            Graphics.FONT_TINY,
            string(Rez.Strings.Brand),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            y + (cardHeight * (compact ? 0.27 : 0.24)).toNumber(),
            scoreFont(width, compact),
            score["display"],
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(RM_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width / 2,
            y + (cardHeight * (compact ? 0.58 : 0.60)).toNumber(),
            Graphics.FONT_TINY,
            metaLabel(score, compact),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        var situation = situationLabel(score["situation"], compact);
        if (situation != null && situation.length() > 0) {
            var chipWidth = (cardWidth * (compact ? 0.78 : 0.72)).toNumber();
            var chipHeight = (cardHeight * (compact ? 0.16 : 0.15)).toNumber();
            var chipX = ((width - chipWidth) / 2).toNumber();
            var chipY = y + (cardHeight * 0.79).toNumber();
            dc.setColor(situationBackground(score["situation"]), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(chipX, chipY, chipWidth, chipHeight, chipHeight / 2);
            dc.setColor(situationColor(score["situation"]), Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                chipY + (chipHeight * 0.05).toNumber(),
                Graphics.FONT_TINY,
                situation,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    private function drawCourtMotif(dc, x, y, width, height) {
        var insetX = (width * 0.13).toNumber();
        var top = y + (height * 0.18).toNumber();
        var courtHeight = (height * 0.62).toNumber();
        var courtWidth = width - (insetX * 2);
        dc.setColor(RM_COURT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x + insetX, top, courtWidth, courtHeight, 4);
        dc.drawLine(width / 2, top, width / 2, top + courtHeight);
        dc.drawLine(x + insetX, top + courtHeight / 2, x + insetX + courtWidth, top + courtHeight / 2);
    }

    private function drawPointControls(dc, width, height, compact) {
        var assigned = _model.assignedTeam();
        if (assigned != null) {
            var accent = assigned.equals("TEAM_A") ? RM_LIME : RM_BLUE;
            var background = assigned.equals("TEAM_A") ? RM_LIME_DARK : RM_BLUE_DARK;
            drawPointButton(
                dc,
                _layout["buttonX"],
                _layout["buttonY"],
                _layout["buttonW"],
                _layout["buttonH"],
                accent,
                background,
                string(Rez.Strings.TeamUs)
            );
            return;
        }

        drawPointButton(
            dc,
            _layout["teamAX"],
            _layout["buttonY"],
            _layout["teamAW"],
            _layout["buttonH"],
            RM_LIME,
            RM_LIME_DARK,
            string(Rez.Strings.TeamUs)
        );
        drawPointButton(
            dc,
            _layout["teamBX"],
            _layout["buttonY"],
            _layout["teamBW"],
            _layout["buttonH"],
            RM_BLUE,
            RM_BLUE_DARK,
            string(Rez.Strings.TeamThem)
        );
    }

    private function drawPointButton(dc, x, y, width, height, accent, background, label) {
        var radius = _compact ? 9 : (height * 0.24).toNumber();
        dc.setColor(background, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, radius);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_compact ? 1 : 2);
        dc.drawRoundedRectangle(x, y, width, height, radius);
        dc.setPenWidth(1);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + width / 2,
            y + (height * 0.50).toNumber(),
            _compact ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM,
            label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function drawFooter(dc, width, height, compact) {
        var y = _layout["footerY"];
        var footerHeight = _layout["footerH"];
        var radius = footerHeight / 2;
        var canUndo = _model.canUndo();

        dc.setColor(canUndo ? RM_PANEL_RAISED : RM_PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_layout["undoX"], y, _layout["undoW"], footerHeight, radius);
        dc.setColor(canUndo ? Graphics.COLOR_WHITE : RM_TEXT_FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _layout["undoX"] + _layout["undoW"] / 2,
            y + (footerHeight * 0.13).toNumber(),
            Graphics.FONT_TINY,
            string(Rez.Strings.Undo),
            Graphics.TEXT_JUSTIFY_CENTER
        );

        dc.setColor(RM_PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_layout["syncX"], y, _layout["syncW"], footerHeight, radius);
        var color = syncColor();
        var dotX = _layout["syncX"] + (footerHeight * 0.42).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, y + footerHeight / 2, compact ? 2 : 3);
        dc.drawText(
            _layout["syncX"] + _layout["syncW"] / 2,
            y + (footerHeight * 0.13).toNumber(),
            Graphics.FONT_TINY,
            string(Rez.Strings.Menu),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function drawComplete(dc, width, height, score, compact) {
        var centerX = width / 2;
        var iconY = (height * (compact ? 0.17 : 0.20)).toNumber();
        var iconRadius = compact ? 13 : (width * 0.055).toNumber();

        dc.setColor(RM_LIME_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, iconY, iconRadius);
        dc.setColor(RM_LIME, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(compact ? 2 : 3);
        dc.drawCircle(centerX, iconY, iconRadius);
        dc.drawLine(centerX - iconRadius / 2, iconY, centerX - 1, iconY + iconRadius / 3);
        dc.drawLine(centerX - 1, iconY + iconRadius / 3, centerX + iconRadius / 2, iconY - iconRadius / 3);
        dc.setPenWidth(1);

        dc.setColor(RM_LIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            (height * (compact ? 0.31 : 0.33)).toNumber(),
            Graphics.FONT_TINY,
            string(Rez.Strings.MatchComplete),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            (height * (compact ? 0.42 : 0.44)).toNumber(),
            scoreFont(width, compact),
            score["display"],
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(RM_TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            (height * (compact ? 0.62 : 0.64)).toNumber(),
            Graphics.FONT_TINY,
            metaLabel(score, compact),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    private function scoreFont(width, compact) {
        if (!compact && width >= 390 && Graphics has :FONT_NUMBER_MILD) {
            return Graphics.FONT_NUMBER_MILD;
        }
        return compact ? Graphics.FONT_MEDIUM : Graphics.FONT_LARGE;
    }

    private function metaLabel(score, compact) {
        var separator = compact ? "  " : "   ";
        return string(Rez.Strings.Set) + " " + score["setsA"].toString() + "-" + score["setsB"].toString()
            + separator + string(Rez.Strings.Game) + " " + score["gamesA"].toString() + "-" + score["gamesB"].toString();
    }

    private function situationLabel(value, compact) {
        if (value == null || value.length() == 0) {
            return null;
        }
        if (value.equals("40 PARI - PUNTO DECISIVO")) {
            return string(compact ? Rez.Strings.DecidingPointShort : Rez.Strings.DecidingPoint);
        }
        if (value.equals("40 PARI - VANTAGGI")) {
            return string(compact ? Rez.Strings.DeuceShort : Rez.Strings.DeuceAdvantages);
        }
        if (value.equals("VANTAGGIO TEAM A")) {
            return advantageLabel("TEAM_A", compact);
        }
        if (value.equals("VANTAGGIO TEAM B")) {
            return advantageLabel("TEAM_B", compact);
        }
        return value;
    }

    private function advantageLabel(team, compact) {
        var assigned = _model.assignedTeam();
        var ours = assigned == null ? team.equals("TEAM_A") : team.equals(assigned);
        if (compact) {
            return string(ours ? Rez.Strings.AdvantageUsShort : Rez.Strings.AdvantageThemShort);
        }
        return string(ours ? Rez.Strings.AdvantageUs : Rez.Strings.AdvantageThem);
    }

    private function situationColor(value) {
        if (value != null && value.equals("VANTAGGIO TEAM B")) {
            return _model.assignedTeam() != null && _model.assignedTeam().equals("TEAM_B") ? RM_LIME : RM_BLUE;
        }
        if (value != null && value.equals("VANTAGGIO TEAM A")) {
            return _model.assignedTeam() != null && _model.assignedTeam().equals("TEAM_B") ? RM_BLUE : RM_LIME;
        }
        return RM_LIME;
    }

    private function situationBackground(value) {
        return situationColor(value) == RM_BLUE ? RM_BLUE_DARK : RM_LIME_DARK;
    }

    private function syncColor() {
        if (_model.isStorageBlocked()) {
            return RM_RED;
        }
        if (_sync.isSending()) {
            return RM_AMBER;
        }
        if (_model.pendingCount() > 0) {
            return RM_ORANGE;
        }
        return RM_GREEN;
    }

    private function syncLabel(compact) {
        if (_model.isStorageBlocked()) {
            return string(compact ? Rez.Strings.MemoryFullShort : Rez.Strings.MemoryFull);
        }
        if (_sync.isSending()) {
            return string(Rez.Strings.Syncing);
        }
        var pending = _model.pendingCount();
        if (pending > 0) {
            return pending.toString() + " " + string(Rez.Strings.Queued);
        }
        return string(Rez.Strings.Synced);
    }

    private function string(resource) {
        return WatchUi.loadResource(resource);
    }
}

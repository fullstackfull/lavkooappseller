abstract class ActionCenterServiceInterface {
  Future getInsights({String? severity, int limit = 50});

  Future dismiss(int id);
}

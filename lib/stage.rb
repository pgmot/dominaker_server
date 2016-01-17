class Stage
  # 1m単位の緯度，経度
  LAT_PER1 = 0.000008983148616
  LNG_PER1 = 0.000010966382364

  # gridのサイズ(メートル
  GRID_SIZE = 3
  Grid = Struct.new(:id, :sw_lat, :sw_lng, :ne_lat, :ne_lng, :color)
  RecoveryArea = Struct.new(:sw_lat, :sw_lng, :ne_lat, :ne_lng)

  # 回復位置のリスト
  ## [フォレスト，コラーニング，CC，ユニオン，リンク]
  BKCRecoveryAreas = [RecoveryArea.new(34.980499, 135.963740, 34.980851, 135.964628), RecoveryArea.new(34.979856, 135.962096, 34.980242, 135.963361), RecoveryArea.new(34.979412, 135.963715, 34.979715, 135.964849), RecoveryArea.new(34.981814, 135.962363, 34.982399, 135.963077), RecoveryArea.new(34.979919, 135.963727, 34.980339, 135.964389)]

  #塗り判定のためのグリッド初期化
  def initialize(lat_start, lng_start, lat_end, lng_end)
    @grids = Array.new

    #インクリメント用の変数
    lat = lat_start
    lng = lng_start

    #何メートル四方のグリッドか
    grid_id = 0
    default_color = -1

    while lat + LAT_PER1*GRID_SIZE <= lat_end do
      while lng + LNG_PER1*GRID_SIZE <= lng_end do
        #ラフグリッドの要素を作成（4辺）
        grid = Grid.new(grid_id, lat, lng, lat + LAT_PER1, lng + LNG_PER1, default_color)
        #一辺の長さ分インクリメント
        lng += LNG_PER1*GRID_SIZE
        grid_id += 1
        @grids << grid
      end
      #一辺の長さ分インクリメント
      lat += LAT_PER1*GRID_SIZE
      #ループのため初期化
      lng = lng_start
    end
  end

  # ステージ増やすならステージID投げてもらってそれに伴い回復エリアを返す感じで
  def recovery_areas
    BKCRecoveryAreas
  end

  def victory_or_defeat
    result = [0,0]
    @grids.each do |grid|
      result[grid.color] += 1 unless grid.color == -1
    end
    result
  end

  def num_of_grids
    @grids.length
  end
end

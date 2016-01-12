class Stage
  # 1m単位の緯度，経度
  LAT_PER1 = 0.000008983148616
  LNG_PER1 = 0.000010966382364

  # gridのサイズ(メートル
  GRID_SIZE = 3
  Grid = Struct.new(:id, :sw_lat, :sw_lng, :ne_lat, :ne_lng, :color)

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

  def num_of_grids
    @grids.length
  end
end

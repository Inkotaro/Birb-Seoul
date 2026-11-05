# Birb-Seoul
<p align="center">
  <img src="Birb-Seoul.png" alt="Birb-Seoul" width="150">
</p>

BIRB SEOUL adalah sebuah game 3D sidescrolling narrative exploration yang mengisahkan seekor roh burung peliharaan yang mati akibat tertabrak mobil. Game ini memiliki mekanik utama berupa procedurally looping 3D street map ala Exit 8, di mana pemain(sang burung) harus menyusuri jalanan kota yang terus berulang dan melewati jasadnya sendiri untuk mengumpulkan serpihan memori di beberapa titik checkpoint tempat dia menghabiskan waktu dulu bersama pemiliknya. Setiap memori yang terkumpul akan memicu sistem dialog dan transisi visual (menggunakan shader) yang mengubah dunia dari hitam putih menjadi full color secara bertahap hingga pemain mencapai klimaks/puncak dari memori di rumah pemiliknya.

Namun, jika pemain terus berjalan dan tidak berinteraksi dengan objek cutscene di titik checkpoint kenangan tersebut, sistem procedural map tidak akan memicu break looping event. Akibatnya, pemain akan terjebak dalam infinite loop (map kota dan lokasi kecelakaan jasad burung akan terus terulang tanpa akhir) sehingga interaksi dengan objek memori di setiap checkpoint harus dilakukan untuk membuka alur memori berikutnya.

## Download
[Release Page](https://github.com/Inkotaro/Birb-Seoul/releases/tag/v2.0.0)

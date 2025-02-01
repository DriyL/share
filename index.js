document.getElementById("judulForm").addEventListener("submit", function(event) {
    event.preventDefault(); // Biar form nggak reload

    // Ambil data dari form
    const pekerjaan = document.getElementById("pekerjaan").value;
    const divisi = document.getElementById("divisi").value;
    const perusahaan = document.getElementById("perusahaan").value;
    const deskripsi = document.getElementById("deskripsi").value;
    const profesionalitas = document.getElementById("profesionalitas").value;
    const istilah = document.getElementById("istilah").value;

    // Cek apakah semua field sudah diisi
    if (!pekerjaan || !divisi || !perusahaan || !deskripsi || !profesionalitas || !istilah) {
        showNotification("Kamu belum mengisi form keseluruhan", "red");
        console.log("gblok");
        return; // Jika ada yang kosong, berhenti di sini
    }

    // Tampilkan box mengambang
    const hasilContainer = document.getElementById("hasilContainer");
    hasilContainer.classList.remove("hidden");

    // Buat prompt berdasarkan data form
    const prompt = `bertindak sebagai seorang profesional di bidang pembuatan judul laporan pkl secara estetik yang membuat orang-orang yang melihat judul tersebut bahkan tidak paham maksudnya karna membingungkan. Itu bisa terjadi karna kamu mengutamakan istilah ilmiah dalam pembuatan judulnya. kamu bisa membuat judul dari yang sangat remeh bahkan anak sd pun paham di tingkat keprofesionalitasan 1, sampai tingkat 10 yang bikin guru geleng-geleng kepala. Dengan 3 tingkat istilah, 0 berarti tidak ada istilah ilmiah yang digunakan, 1 berarti istilah yang digunakan masih bisa dipahami orang awam, atau 2 tingkat istilah ilmiah yang sangat kompleks bikin guru geleng-geleng kepala. Aku ingin kamu buatkan aku judul berdasarkan informaasi berikut: Aku pkl di ${perusahaan}, kerjaanku adalah ${pekerjaan}, divisi tempat pkl ku adalah ${divisi}, detail kerjaanku yang bisa aku berikan kurang lebih adalah ${deskripsi}. Dengan tingkat keprofesionalitasan ${profesionalitas} dan dengan tingkat istilah ${istilah}.Mohon buatkan 5 list judul profesional berdasarkan yang kusuruh, jika kamu paham, hanya buat 5 judul tanpa penjelasan dan respon lebih lanjut cukup susun teks bertingkat tanpa whitespace dan tanpa diberi bullets point atau char apapun termasuk angka, jika kamu mengerti lakukan`;

    // Kirim request ke OpenAI API
    fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer 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`, // Ganti dengan API key kamu
        },
        body: JSON.stringify({
            model: "gpt-4o-mini",
            messages: [{ role: "user", content: prompt }],
            temperature: 0.7
        }),
    })
    .then(response => response.json())
    .then(data => {
        // Ambil hasil judul dari OpenAI
        const generatedTitles = data.choices[0].message.content.trim().split("\n");

        // Buat list hasil dalam bullet points
        let resultList = "<ul>";
        generatedTitles.forEach(title => {
            resultList += `<li>${title}</li>`;
        });
        resultList += "</ul>";

        // Tampilkan hasil dalam box mengambang
        // hasilContainer.style.textAlign = "left";
        // hasilContainer.style.padding = "35px";
        // hasilContainer.style.top = "0";
        document.getElementById("hasilJudul").innerHTML = resultList;
        let load = document.getElementById("load");
        load.innerText = "🎯 Judul Laporan PKL Kamu:";
    })
    .catch(error => {
        // Tangani error jika ada
        console.error("Error:", error);
        document.getElementById("hasilJudul").innerHTML = "<p>Terjadi kesalahan, coba lagi.</p>";
    });
});

// Fungsi untuk menampilkan notifikasi di atas konten
function showNotification(message, color) {
    let hasilContainer = document.getElementById("hasilContainer");
    hasilContainer.innerText = message;
    hasilContainer.style.backgroundColor = color;
    hasilContainer.style.color = "white";
    hasilContainer.style.position = "fixed";
    hasilContainer.style.top = "0";
    hasilContainer.style.left = "0";
    hasilContainer.style.padding = "10px";
    hasilContainer.style.textAlign = "center";
    hasilContainer.style.opacity = "1";
    hasilContainer.style.transition = "opacity 3s ease-out";
    hasilContainer.classList.remove("hidden");

    setTimeout(function() {
        hasilContainer.style.opacity = "0";
    }, 3000);
}

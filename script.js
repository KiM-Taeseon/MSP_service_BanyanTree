document.getElementById("awsForm").addEventListener("submit", async function (event) {
    event.preventDefault();

    const userId = document.getElementById("userId").value.trim();
    const ec2 = parseInt(document.getElementById("ec2").value);
    const ec2type = document.getElementById("ec2type").value;
    const s3 = parseInt(document.getElementById("s3").value);
    const rds = parseInt(document.getElementById("rds").value);

    try {
        const res = await fetch("https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/pricing/aws_price_data.json");

        if (!res.ok) throw new Error(`HTTP 오류: ${res.status}`);

        const pricing = await res.json();
        const summary = {};

        for (const [region, data] of Object.entries(pricing)) {
            const total =
                (data.ec2?.[ec2type] ?? 0) * ec2 +
                (data.s3 ?? 0) * s3 +
                (data.rds ?? 0) * rds;
            summary[region] = parseFloat(total.toFixed(4));
        }

        const sorted = Object.entries(summary).sort((a, b) => a[1] - b[1]);
        const cheapest = sorted[0];
        const top3_region = sorted.slice(0, 3).map(([region]) => region);

        const topRegionsDiv = document.getElementById("topRegions");
        topRegionsDiv.innerHTML = "<h2>📍 Top 3 저렴한 리전</h2>";

        sorted.slice(0, 3).forEach(([region, price]) => {
            const div = document.createElement("div");
            div.className = "region-item";
            div.innerText = `${region} ($${price})`;
            div.dataset.region = region;

            div.addEventListener("mouseenter", () => {
                document.getElementById("diagramImage").src = `https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/arch-${region}.png`;
            });

            div.addEventListener("mouseleave", () => {
                document.getElementById("diagramImage").src = "https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/multi-az_web_architecture.png";
            });

            // ✅ 리전 클릭 시 입력창 보이기
            div.addEventListener("click", () => {
                document.getElementById("regionInputSection").style.display = "block";
                document.getElementById("selectedRegion").value = region;
            });

            topRegionsDiv.appendChild(div);
        });

        let resultHTML = `<h2>📍 최저가 리전: ${cheapest[0]} ($${cheapest[1]})</h2>`;
        resultHTML += `<table><thead><tr><th>리전</th><th>총 비용 ($)</th></tr></thead><tbody>`;
        for (const [region, price] of Object.entries(summary)) {
            resultHTML += `<tr><td>${region}</td><td>$${price}</td></tr>`;
        }
        resultHTML += '</tbody></table>';
        document.getElementById("output").innerHTML = resultHTML;

        // ✅ 첫 번째 입력 저장 (비용 계산 기준)
        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id: userId, ec2, ec2type, s3, rds, top3_region })
        });

    } catch (error) {
        document.getElementById("output").innerHTML = `<p style="color:red">❗ 오류: ${error.message}</p>`;
    }
});

// ✅ 최종 입력 정보 저장 (선택한 리전 + 깃허브 URL + 액세스 키)
document.getElementById("confirmSelection").addEventListener("click", async function () {
    const userId = document.getElementById("userId").value.trim();
    const selectedRegion = document.getElementById("selectedRegion").value;
    const githubUrl = document.getElementById("githubUrl").value.trim();
    const accessKey = document.getElementById("accessKey").value.trim();

    if (!selectedRegion || !githubUrl || !accessKey) {
        alert("모든 항목을 입력해야 합니다.");
        return;
    }

    try {
        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                id: userId,
                selectedRegion,
                githubUrl,
                accessKey
            })
        });

        alert("✅ 최종 정보가 저장되었습니다!");
    } catch (err) {
        alert("❌ 저장 실패: " + err.message);
    }
});


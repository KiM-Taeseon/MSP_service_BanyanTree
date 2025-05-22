document.getElementById("awsForm").addEventListener("submit", async function (event) {
    event.preventDefault();

    const userId = document.getElementById("userId").value.trim();
    const ec2 = parseInt(document.getElementById("ec2").value);
    const ec2type = document.getElementById("ec2type").value;
    const s3 = parseInt(document.getElementById("s3").value);
    const rds = parseInt(document.getElementById("rds").value);

    try {
        const res = await fetch("http://www.jongseo22.com/aws_price_data.json");
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
        topRegionsDiv.innerHTML = "<h2>Top 3 저렴한 리전</h2>";

        sorted.slice(0, 3).forEach(([region, price]) => {
            const div = document.createElement("div");
            div.className = "region-item";
            div.innerText = `${region} ($${price})`;
            div.dataset.region = region;

            // 마우스 올릴 때 이미지 표시
            div.addEventListener("mouseenter", () => {
                const oldImg = document.getElementById("diagramImage");
                if (oldImg) oldImg.remove();

                const img = document.createElement("img");
                img.id = "diagramImage";
                img.src = `/diagrams/${region}.png?t=${Date.now()}`;
                img.alt = "Architecture Diagram";
                img.style.position = "absolute";
                img.style.bottom = "20px";
                img.style.right = "20px";
                img.style.width = "50%";
                img.style.maxHeight = "60%";
                img.style.objectFit = "contain";
                img.style.border = "1px solid #ccc";
                img.style.padding = "8px";
                img.style.background = "#fff";
                document.querySelector(".right-pane").appendChild(img);
            });

            div.addEventListener("mouseleave", () => {
                const img = document.getElementById("diagramImage");
                if (img) img.remove();
            });

            // ✅ 클릭 시 region 정보만 next.html로 전달
            div.addEventListener("click", () => {
                const query = new URLSearchParams({
                    region
                }).toString();
                window.location.href = `/next.html?${query}`;
            });

            topRegionsDiv.appendChild(div);
        });

        // 결과 테이블 출력
        let resultHTML = `<h2>최저가 리전: ${cheapest[0]} ($${cheapest[1]})</h2>`;
        resultHTML += `<table><thead><tr><th>리전</th><th>총 비용 ($)</th></tr></thead><tbody>`;
        for (const [region, price] of Object.entries(summary)) {
            resultHTML += `<tr><td>${region}</td><td>$${price}</td></tr>`;
        }
        resultHTML += '</tbody></table>';
        document.getElementById("output").innerHTML = resultHTML;

        // 백엔드 저장 요청 (선택 전까지만)
        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ userId, ec2, ec2type, s3, rds, top3_region })
        });

    } catch (error) {
        document.getElementById("output").innerHTML = `<p style="color:red">❗ 오류: ${error.message}</p>`;
    }
});


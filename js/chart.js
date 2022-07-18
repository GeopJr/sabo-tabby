import {
    Chart,
    BarElement,
    BarController,
    CategoryScale,
    LinearScale,
    Legend,
    Tooltip,
} from 'chart.js';
import ChartDeferred from 'chartjs-plugin-deferred';

Chart.register(
    BarElement,
    BarController,
    CategoryScale,
    LinearScale,
    Legend,
    Tooltip,
    ChartDeferred
);

const ctx = document.getElementById('myChart').getContext('2d');
new Chart(ctx, {
    type: 'bar',
    data: {
        labels: ["Sabo-Tabby", "Warp", "Nginx", "Httpd", "Jester", "Polka", "Jaguar", "Express", "Sinatra"],
        datasets: [{
            label: 'Requests Per Second',
            data: [69247.21, 68707.8, 49369.32, 28352.63, 18059.06, 9323.28, 4765.79, 3897.06, 2514.95],
            backgroundColor: [
                'rgba(255, 255, 255, .5)',
                'rgba(222, 165, 132, .5)',
                'rgba(0, 150, 57, .5)',
                'rgba(170, 0, 0, .5)',
                'rgba(255, 194, 0, .5)',
                'rgba(241, 224, 90, .5)',
                'rgba(0, 180, 171, .5)',
                'rgba(241, 224, 90, .5)',
                'rgba(112, 21, 22, .5)',
            ],
            borderColor: [
                'rgba(255, 255, 255, 1)',
                'rgba(222, 165, 132, 1)',
                'rgba(0, 150, 57, 1)',
                'rgba(170, 0, 0, 1)',
                'rgba(255, 194, 0, 1)',
                'rgba(241, 224, 90, 1)',
                'rgba(0, 180, 171, 1)',
                'rgba(241, 224, 90, 1)',
                'rgba(112, 21, 22, 1)',
            ],
            borderWidth: 1,
            tickColor: "#fff",
            borderRadius: 100,
        }]
    },
    options: {
        indexAxis: 'y',
        scales: {
            x: {
                beginAtZero: true,
                reverse: true,
                ticks: {
                    color: "#fff"
                },
            },
            y: {
                position: 'right',
                ticks: {
                    color: "#fff"
                },
            }
        },
        plugins: {
            deferred: {
                delay: 100,
                yOffset: "90%",
                xOffset: "90%",
            },
            legend: {
                labels: {
                    color: 'white',
                    boxWidth: 0,
                    boxHeight: 0,
                }
            }
        }
    }
});
